import std/[hashes, math, strformat, tables, posix]

import pkg/pixie
import pkg/pixie/simd
import pkg/chroma
import pkg/chronicles
import pkg/vulkan
import pkg/vulkan/wrapper

import ../commons
import ../figbackend as figbackend
import ../common/formatflippy
import ../fignodes
import ../utils/drawextras
import ./vulkan_blur
import ./vulkan_resources
import ./vulkan_utils

export drawextras
export vulkan_utils

logScope:
  scope = "vulkan"

const
  quadLimit = 10_921
  sdfVertSpv = staticRead("shaders/sdf.vert.spv")
  sdfFragSpv = staticRead("shaders/sdf.frag.spv")
  blurVertSpv = staticRead("shaders/blur.vert.spv")
  blurFragSpv = staticRead("shaders/blur.frag.spv")
  VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT =
    0x00020000.VkExternalMemoryHandleTypeFlags

type
  VkExternalMemoryImageCreateInfo = object
    sType: VkStructureType
    pNext: pointer
    handleTypes: VkExternalMemoryHandleTypeFlags

  VkExportMemoryAllocateInfo = object
    sType: VkStructureType
    pNext: pointer
    handleTypes: VkExternalMemoryHandleTypeFlags

  VkMemoryGetFdInfoKHR = object
    sType: VkStructureType
    pNext: pointer
    memory: VkDeviceMemory
    handleType: VkExternalMemoryHandleTypeFlags

when defined(emscripten):
  type SdfModeData = float32
else:
  type SdfModeData = uint16

type SdfMode* = figbackend.SdfMode

type RectMaskKind = enum
  rmkFast
  rmkMask

type RectMask = object
  kind: RectMaskKind
  params: Vec4
  radii: Vec4
  matX: Vec4
  matY: Vec4

type
  VSUniforms = object
    proj: Mat4

  FSUniforms = object
    windowFrame: Vec2
    aaFactor: float32
    maskTexEnabled: uint32

  BlurUniforms = object
    texelStep: Vec2
    blurRadius: float32
    pad0: float32

  Vertex = object
    pos: array[2, float32]
    uv: array[2, float32]
    color: array[4, uint8]
    fillMidColor: array[4, uint8]
    fillStopColor: array[4, uint8]
    sdfParams: array[4, float32]
    sdfRadii: array[4, float32]
    sdfMode: uint16
    sdfPad: uint16
    sdfFactors: array[2, float32]
    rectMaskParams: array[4, float32]
    rectMaskRadii: array[4, float32]
    rectMaskMatX: array[4, float32]
    rectMaskMatY: array[4, float32]

  VulkanContext* = ref object of figbackend.BackendContext
    atlasSize: int
    initialAtlasSize: int
    atlasMargin: int
    quadCount: int
    maxQuads: int
    mat*: Mat4
    mats: seq[Mat4]
    entries*: Table[Hash, Rect]
    atlasEntryMeta: Table[Hash, AtlasEntryMeta]
    heights: seq[uint16]
    proj*: Mat4
    frameSize: Vec2
    frameBegun: bool
    maskBegun: bool
    maskDepth: int
    pendingMaskRect: Rect
    pendingMaskValid: bool
    clipRects: seq[Rect]
    pixelate*: bool
    pixelScale*: float32
    aaFactor: float32
    textLcdFilteringEnabled: bool
    textSubpixelPositioningEnabled: bool
    textSubpixelGlyphVariantsEnabled: bool
    textSubpixelShift: float32

    positions: seq[float32]
    colors: seq[uint8]
    fillMidColors: seq[uint8]
    fillStopColors: seq[uint8]
    uvs: seq[float32]
    sdfParams: seq[float32]
    sdfRadii: seq[float32]
    sdfModeAttr: seq[SdfModeData]
    sdfFactors: seq[float32]
    rectMaskParams: seq[float32]
    rectMaskRadii: seq[float32]
    rectMaskMatX: seq[float32]
    rectMaskMatY: seq[float32]
    rectMaskStack: seq[RectMask]
    batchHasRectMask: bool
    indices: seq[uint16]
    vertexScratch: seq[Vertex]

    atlasPixels: Image
    atlasDirty: bool
    atlasLayoutReady: bool

    instance: VkInstance
    physicalDevice: VkPhysicalDevice
    device: VkDevice
    queue: VkQueue
    queueFamily: uint32

    targetImage: VkImage
    targetMemory: VkDeviceMemory
    targetView: VkImageView
    targetFramebuffer: VkFramebuffer
    targetFormat: VkFormat
    targetExtent: VkExtent2D
    targetRequestedWidth: int32
    targetRequestedHeight: int32
    targetFd: int32
    driverInfo: VulkanDriverInfo

    frameIndex: int
    swapImages: array[2, VkImage]
    swapMemories: array[2, VkDeviceMemory]
    swapViews: array[2, VkImageView]
    swapFramebuffers: array[2, VkFramebuffer]
    swapFds: array[2, int32]
    swapCommandBuffers: array[2, VkCommandBuffer]
    swapSemaphores: array[2, VkSemaphore]
    swapFences: array[2, VkFence]

    renderPass: VkRenderPass
    descriptorSetLayout: VkDescriptorSetLayout
    descriptorPool: VkDescriptorPool
    descriptorSet: VkDescriptorSet
    pipelineLayout: VkPipelineLayout
    pipeline: VkPipeline
    vertShader: VkShaderModule
    fragShader: VkShaderModule

    commandPool: VkCommandPool
    commandBuffer: VkCommandBuffer
    renderFinishedSemaphore: VkSemaphore
    inFlightFence: VkFence
    commandRecording: bool
    renderPassBegun: bool
    frameNeedsClear: bool
    frameClearColor: Color
    readbackBuffer: VulkanBuffer
    readbackBytes: VkDeviceSize
    readbackWidth: int32
    readbackHeight: int32
    readbackReady: bool

    atlasImage: VulkanImage
    backdropImage: VulkanImage
    backdropBlurTempImage: VulkanImage
    backdropLayoutReady: bool
    backdropBlurTempLayoutReady: bool
    backdropWidth: int32
    backdropHeight: int32
    backdropFormat: VkFormat
    backdropBlurFramebuffer: VkFramebuffer
    backdropBlurTempFramebuffer: VkFramebuffer
    blurRenderPass: VkRenderPass
    blurDescriptorSetLayout: VkDescriptorSetLayout
    blurDescriptorPool: VkDescriptorPool
    blurDescriptorSets: array[2, VkDescriptorSet]
    blurPipelineLayout: VkPipelineLayout
    blurPipeline: VkPipeline
    blurVertShader: VkShaderModule
    blurFragShader: VkShaderModule
    blurUniformBuffers: array[2, VulkanBuffer]
    atlasSampler: VkSampler
    atlasUploadBuffer: VulkanBuffer
    atlasUploadBytes: VkDeviceSize

    vertexBuffer: VulkanBuffer
    vertexBufferBytes: VkDeviceSize
    frameVertexBuffers: seq[VulkanBuffer]
    indexBuffer: VulkanBuffer
    indexBufferBytes: VkDeviceSize
    vsUniformBuffer: VulkanBuffer
    fsUniformBuffer: VulkanBuffer

    gpuReady: bool

var vkGetMemoryFdKHR_dyn: proc(
  device: VkDevice, pGetFdInfo: ptr VkMemoryGetFdInfoKHR, pFd: ptr cint
): VkResult {.stdcall.}

const
  vkNullInstance = VkInstance(0)
  vkNullPhysicalDevice = VkPhysicalDevice(0)
  vkNullDevice = VkDevice(0)
  vkNullQueue = VkQueue(0)
  vkNullSurface = VkSurfaceKHR(0)
  vkNullRenderPass = VkRenderPass(0)
  vkNullFramebuffer = VkFramebuffer(0)
  vkNullImageView = VkImageView(0)
  vkNullSampler = VkSampler(0)
  vkNullBuffer = VkBuffer(0)
  vkNullMemory = VkDeviceMemory(0)
  vkNullDescriptorSetLayout = VkDescriptorSetLayout(0)
  vkNullDescriptorPool = VkDescriptorPool(0)
  vkNullDescriptorSet = VkDescriptorSet(0)
  vkNullPipelineLayout = VkPipelineLayout(0)
  vkNullPipeline = VkPipeline(0)
  vkNullShaderModule = VkShaderModule(0)
  vkNullCommandPool = VkCommandPool(0)
  vkNullCommandBuffer = VkCommandBuffer(0)
  vkNullSemaphore = VkSemaphore(0)
  vkNullFence = VkFence(0)
  vkNullImage = VkImage(0)

proc exportBufferFd*(ctx: VulkanContext): int32 =
  ctx.targetFd

proc exportBufferStride*(ctx: VulkanContext): uint32 =
  var subresource = VkImageSubresource(
    aspectMask: VkImageAspectFlags{ColorBit}, mipLevel: 0, arrayLayer: 0
  )
  var layout: VkSubresourceLayout
  vkGetImageSubresourceLayout(
    ctx.device, ctx.targetImage, subresource.addr, layout.addr
  )
  return cast[uint32](layout.rowPitch)

method hasImage*(ctx: VulkanContext, key: Hash): bool =
  key in ctx.entries

proc tryGetImageRect(ctx: VulkanContext, imageId: Hash, rect: var Rect): bool
proc updateDescriptorSet(ctx: VulkanContext)
proc updateBlurDescriptorSet(
  ctx: VulkanContext,
  descriptorSet: VkDescriptorSet,
  srcView: VkImageView,
  uniformBuffer: VkBuffer,
)

proc updateBlurDescriptorSets(ctx: VulkanContext)
proc recreateBlurFramebuffers(ctx: VulkanContext)
proc createImageView(
  ctx: VulkanContext, image: VkImage, format: VkFormat, aspectMask: VkImageAspectFlags
): VkImageView

proc createBuffer(
    ctx: VulkanContext,
    size: VkDeviceSize,
    usage: VkBufferUsageFlags,
    properties: VkMemoryPropertyFlags,
): VulkanBuffer =
  result = newVulkanBuffer(ctx.device, size)
  let bufferInfo = newVkBufferCreateInfo(
    size = size,
    usage = usage,
    sharingMode = VkSharingMode.Exclusive,
    queueFamilyIndices = [],
  )
  result.handle = createBuffer(ctx.device, bufferInfo)

  let req = getBufferMemoryRequirements(ctx.device, result.handle)
  let alloc = newVkMemoryAllocateInfo(
    allocationSize = req.size,
    memoryTypeIndex = findMemoryType(ctx.physicalDevice, req.memoryTypeBits, properties),
  )
  result.allocation = allocateMemory(ctx.device, alloc)
  bindBufferMemory(ctx.device, result.handle, result.allocation, 0.VkDeviceSize)

proc createImage(
    ctx: VulkanContext,
    width, height: uint32,
    format: VkFormat,
    tiling: VkImageTiling,
    usage: VkImageUsageFlags,
    properties: VkMemoryPropertyFlags,
): VulkanImage =
  result = newVulkanImage(ctx.device)
  let info = newVkImageCreateInfo(
    imageType = VK_IMAGE_TYPE_2D,
    format = format,
    extent = newVkExtent3D(width = width, height = height, depth = 1),
    mipLevels = 1,
    arrayLayers = 1,
    samples = VK_SAMPLE_COUNT_1_BIT,
    tiling = tiling,
    usage = usage,
    sharingMode = VkSharingMode.Exclusive,
    queueFamilyIndices = [],
    initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
  )
  checkVkResult vkCreateImage(ctx.device, info.addr, nil, result.handle.addr)

  var req: VkMemoryRequirements
  vkGetImageMemoryRequirements(ctx.device, result.handle, req.addr)
  let alloc = newVkMemoryAllocateInfo(
    allocationSize = req.size,
    memoryTypeIndex = findMemoryType(ctx.physicalDevice, req.memoryTypeBits, properties),
  )
  checkVkResult vkAllocateMemory(ctx.device, alloc.addr, nil, result.allocation.addr)
  checkVkResult vkBindImageMemory(
    ctx.device, result.handle, result.allocation, 0.VkDeviceSize
  )
  result.view = ctx.createImageView(result.handle, format, VkImageAspectFlags{ColorBit})

proc createImageView(
    ctx: VulkanContext, image: VkImage, format: VkFormat, aspectMask: VkImageAspectFlags
): VkImageView =
  let info = newVkImageViewCreateInfo(
    image = image,
    viewType = VK_IMAGE_VIEW_TYPE_2D,
    format = format,
    components = newVkComponentMapping(
      VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY,
      VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY,
    ),
    subresourceRange = newVkImageSubresourceRange(
      aspectMask = aspectMask,
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  checkVkResult vkCreateImageView(ctx.device, info.addr, nil, result.addr)

proc recreateBlurFramebuffers(ctx: VulkanContext) =
  vulkanBlurRecreateFramebuffers(ctx)

proc ensureBackdropImage(ctx: VulkanContext, width, height: int32) =
  let w = max(1'i32, width)
  let h = max(1'i32, height)
  let backdropFormat =
    if ctx.targetFormat != VK_FORMAT_UNDEFINED:
      ctx.targetFormat
    else:
      VK_FORMAT_R8G8B8A8_UNORM
  if not ctx.backdropImage.isNilOrEmpty and ctx.backdropImage.view != vkNullImageView and
      not ctx.backdropBlurTempImage.isNilOrEmpty and
      ctx.backdropBlurTempImage.view != vkNullImageView and ctx.backdropWidth == w and
      ctx.backdropHeight == h and ctx.backdropFormat == backdropFormat:
    return

  if ctx.backdropBlurFramebuffer != vkNullFramebuffer:
    vkDestroyFramebuffer(ctx.device, ctx.backdropBlurFramebuffer, nil)
    ctx.backdropBlurFramebuffer = vkNullFramebuffer
  if ctx.backdropBlurTempFramebuffer != vkNullFramebuffer:
    vkDestroyFramebuffer(ctx.device, ctx.backdropBlurTempFramebuffer, nil)
    ctx.backdropBlurTempFramebuffer = vkNullFramebuffer

  ctx.backdropBlurTempImage = nil
  ctx.backdropImage = nil

  let backdropAlloc = ctx.createImage(
    width = w.uint32,
    height = h.uint32,
    format = backdropFormat,
    tiling = VK_IMAGE_TILING_LINEAR,
    usage = VkImageUsageFlags{SampledBit, TransferDstBit, ColorAttachmentBit},
    properties = VkMemoryPropertyFlags{DeviceLocalBit},
  )
  let backdropTempAlloc = ctx.createImage(
    width = w.uint32,
    height = h.uint32,
    format = backdropFormat,
    tiling = VK_IMAGE_TILING_LINEAR,
    usage = VkImageUsageFlags{SampledBit, ColorAttachmentBit},
    properties = VkMemoryPropertyFlags{DeviceLocalBit},
  )
  ctx.backdropImage = backdropAlloc
  ctx.backdropBlurTempImage = backdropTempAlloc
  ctx.backdropLayoutReady = false
  ctx.backdropBlurTempLayoutReady = false
  ctx.backdropWidth = w
  ctx.backdropHeight = h
  ctx.backdropFormat = backdropFormat
  ctx.recreateBlurFramebuffers()
  if ctx.descriptorSet != vkNullDescriptorSet:
    ctx.updateDescriptorSet()
  ctx.updateBlurDescriptorSets()

proc fullFrameRect(ctx: VulkanContext): Rect =
  rect(0.0'f32, 0.0'f32, ctx.frameSize.x, ctx.frameSize.y)

proc destroyOffscreenTarget(ctx: VulkanContext) =
  for i in 0 ..< 2:
    if ctx.swapFramebuffers[i] != vkNullFramebuffer:
      vkDestroyFramebuffer(ctx.device, ctx.swapFramebuffers[i], nil)
      ctx.swapFramebuffers[i] = vkNullFramebuffer
    if ctx.swapViews[i] != vkNullImageView:
      vkDestroyImageView(ctx.device, ctx.swapViews[i], nil)
      ctx.swapViews[i] = vkNullImageView
    if ctx.swapImages[i] != vkNullImage:
      vkDestroyImage(ctx.device, ctx.swapImages[i], nil)
      ctx.swapImages[i] = vkNullImage
    if ctx.swapMemories[i] != vkNullMemory:
      vkFreeMemory(ctx.device, ctx.swapMemories[i], nil)
      ctx.swapMemories[i] = vkNullMemory
    if ctx.swapFds[i] != -1:
      discard posix.close(ctx.swapFds[i].cint)
      ctx.swapFds[i] = -1

  ctx.targetFramebuffer = vkNullFramebuffer
  ctx.targetView = vkNullImageView
  ctx.targetImage = vkNullImage
  ctx.targetMemory = vkNullMemory
  ctx.targetFd = -1

proc destroyPipelineObjects(ctx: VulkanContext) =
  if ctx.backdropBlurFramebuffer != vkNullFramebuffer:
    vkDestroyFramebuffer(ctx.device, ctx.backdropBlurFramebuffer, nil)
    ctx.backdropBlurFramebuffer = vkNullFramebuffer
  if ctx.backdropBlurTempFramebuffer != vkNullFramebuffer:
    vkDestroyFramebuffer(ctx.device, ctx.backdropBlurTempFramebuffer, nil)
    ctx.backdropBlurTempFramebuffer = vkNullFramebuffer

  if ctx.blurPipeline != vkNullPipeline:
    vkDestroyPipeline(ctx.device, ctx.blurPipeline, nil)
    ctx.blurPipeline = vkNullPipeline
  if ctx.blurPipelineLayout != vkNullPipelineLayout:
    vkDestroyPipelineLayout(ctx.device, ctx.blurPipelineLayout, nil)
    ctx.blurPipelineLayout = vkNullPipelineLayout
  if ctx.blurRenderPass != vkNullRenderPass:
    vkDestroyRenderPass(ctx.device, ctx.blurRenderPass, nil)
    ctx.blurRenderPass = vkNullRenderPass

  if ctx.pipeline != vkNullPipeline:
    vkDestroyPipeline(ctx.device, ctx.pipeline, nil)
    ctx.pipeline = vkNullPipeline
  if ctx.pipelineLayout != vkNullPipelineLayout:
    vkDestroyPipelineLayout(ctx.device, ctx.pipelineLayout, nil)
    ctx.pipelineLayout = vkNullPipelineLayout
  if ctx.renderPass != vkNullRenderPass:
    vkDestroyRenderPass(ctx.device, ctx.renderPass, nil)
    ctx.renderPass = vkNullRenderPass

proc updateDescriptorSet(ctx: VulkanContext) =
  var vsInfo = newVkDescriptorBufferInfo(
    buffer = ctx.vsUniformBuffer.handle,
    offset = 0.VkDeviceSize,
    range = VkDeviceSize(sizeof(VSUniforms)),
  )
  var fsInfo = newVkDescriptorBufferInfo(
    buffer = ctx.fsUniformBuffer.handle,
    offset = 0.VkDeviceSize,
    range = VkDeviceSize(sizeof(FSUniforms)),
  )
  var atlasImageInfo = newVkDescriptorImageInfo(
    sampler = ctx.atlasSampler,
    imageView = ctx.atlasImage.view,
    imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
  )
  var backdropImageInfo = newVkDescriptorImageInfo(
    sampler = ctx.atlasSampler,
    imageView =
      if not ctx.backdropImage.isNilOrEmpty:
        ctx.backdropImage.view
      else:
        ctx.atlasImage.view,
    imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
  )

  let writes = [
    newVkWriteDescriptorSet(
      dstSet = ctx.descriptorSet,
      dstBinding = 0,
      dstArrayElement = 0,
      descriptorCount = 1,
      descriptorType = VkDescriptorType.UniformBuffer,
      pImageInfo = nil,
      pBufferInfo = vsInfo.addr,
      pTexelBufferView = nil,
    ),
    newVkWriteDescriptorSet(
      dstSet = ctx.descriptorSet,
      dstBinding = 1,
      dstArrayElement = 0,
      descriptorCount = 1,
      descriptorType = VkDescriptorType.UniformBuffer,
      pImageInfo = nil,
      pBufferInfo = fsInfo.addr,
      pTexelBufferView = nil,
    ),
    newVkWriteDescriptorSet(
      dstSet = ctx.descriptorSet,
      dstBinding = 2,
      dstArrayElement = 0,
      descriptorCount = 1,
      descriptorType = VkDescriptorType.CombinedImageSampler,
      pImageInfo = atlasImageInfo.addr,
      pBufferInfo = nil,
      pTexelBufferView = nil,
    ),
    newVkWriteDescriptorSet(
      dstSet = ctx.descriptorSet,
      dstBinding = 3,
      dstArrayElement = 0,
      descriptorCount = 1,
      descriptorType = VkDescriptorType.CombinedImageSampler,
      pImageInfo = atlasImageInfo.addr,
      pBufferInfo = nil,
      pTexelBufferView = nil,
    ),
    newVkWriteDescriptorSet(
      dstSet = ctx.descriptorSet,
      dstBinding = 4,
      dstArrayElement = 0,
      descriptorCount = 1,
      descriptorType = VkDescriptorType.CombinedImageSampler,
      pImageInfo = backdropImageInfo.addr,
      pBufferInfo = nil,
      pTexelBufferView = nil,
    ),
  ]
  updateDescriptorSets(ctx.device, writes, [])

proc updateBlurDescriptorSet(
    ctx: VulkanContext,
    descriptorSet: VkDescriptorSet,
    srcView: VkImageView,
    uniformBuffer: VkBuffer,
) =
  vulkanBlurUpdateDescriptorSet(ctx, descriptorSet, srcView, uniformBuffer)

proc updateBlurDescriptorSets(ctx: VulkanContext) =
  vulkanBlurUpdateDescriptorSets(ctx)

proc writeBlurUniforms(
    ctx: VulkanContext,
    uniformMemory: VkDeviceMemory,
    texelStep: Vec2,
    blurRadius: float32,
) =
  vulkanBlurWriteUniforms(ctx, uniformMemory, texelStep, blurRadius)

proc createBlurPipeline(ctx: VulkanContext) =
  vulkanBlurCreatePipeline(ctx)

proc recreateAtlasGpu(ctx: VulkanContext) =
  ctx.atlasImage = nil

  let atlasAlloc = ctx.createImage(
    width = ctx.atlasSize.uint32,
    height = ctx.atlasSize.uint32,
    format = VK_FORMAT_R8G8B8A8_UNORM,
    tiling = VK_IMAGE_TILING_LINEAR,
    usage = VkImageUsageFlags{SampledBit, TransferDstBit},
    properties = VkMemoryPropertyFlags{DeviceLocalBit},
  )
  ctx.atlasImage = atlasAlloc
  ctx.atlasDirty = true
  ctx.atlasLayoutReady = false
  if ctx.descriptorSet != vkNullDescriptorSet:
    ctx.updateDescriptorSet()

proc createPipeline(ctx: VulkanContext) =
  ctx.destroyPipelineObjects()

  var colorAttachment = VkAttachmentDescription(
    flags: 0.VkAttachmentDescriptionFlags,
    format: ctx.targetFormat,
    samples: VK_SAMPLE_COUNT_1_BIT,
    loadOp: VK_ATTACHMENT_LOAD_OP_LOAD,
    storeOp: VK_ATTACHMENT_STORE_OP_STORE,
    stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
    stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
    initialLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    finalLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
  )
  var colorAttachmentRef = VkAttachmentReference(
    attachment: 0, layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
  )
  var subpass = VkSubpassDescription(
    flags: 0.VkSubpassDescriptionFlags,
    pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
    inputAttachmentCount: 0,
    pInputAttachments: nil,
    colorAttachmentCount: 1,
    pColorAttachments: colorAttachmentRef.addr,
    pResolveAttachments: nil,
    pDepthStencilAttachment: nil,
    preserveAttachmentCount: 0,
    pPreserveAttachments: nil,
  )
  var dependency = VkSubpassDependency(
    srcSubpass: VK_SUBPASS_EXTERNAL,
    dstSubpass: 0,
    srcStageMask: VkPipelineStageFlags{ColorAttachmentOutputBit},
    dstStageMask: VkPipelineStageFlags{ColorAttachmentOutputBit},
    srcAccessMask: 0.VkAccessFlags,
    dstAccessMask: VkAccessFlags{ColorAttachmentReadBit, ColorAttachmentWriteBit},
    dependencyFlags: 0.VkDependencyFlags,
  )

  let renderPassInfo = newVkRenderPassCreateInfo(
    attachments = [colorAttachment], subpasses = [subpass], dependencies = [dependency]
  )
  checkVkResult vkCreateRenderPass(
    ctx.device, renderPassInfo.addr, nil, ctx.renderPass.addr
  )

  if ctx.vertShader == vkNullShaderModule:
    let vertInfo = newVkShaderModuleCreateInfo(code = sdfVertSpv)
    ctx.vertShader = createShaderModule(ctx.device, vertInfo)
  if ctx.fragShader == vkNullShaderModule:
    let fragInfo = newVkShaderModuleCreateInfo(code = sdfFragSpv)
    ctx.fragShader = createShaderModule(ctx.device, fragInfo)

  let vertStage = newVkPipelineShaderStageCreateInfo(
    stage = VkShaderStageFlagBits.VertexBit,
    module = ctx.vertShader,
    pName = "main",
    pSpecializationInfo = nil,
  )
  let fragStage = newVkPipelineShaderStageCreateInfo(
    stage = VkShaderStageFlagBits.FragmentBit,
    module = ctx.fragShader,
    pName = "main",
    pSpecializationInfo = nil,
  )

  let bindingDesc = VkVertexInputBindingDescription(
    binding: 0, stride: uint32(sizeof(Vertex)), inputRate: VK_VERTEX_INPUT_RATE_VERTEX
  )

  let attrDescs = [
    VkVertexInputAttributeDescription(
      location: 0,
      binding: 0,
      format: VK_FORMAT_R32G32_SFLOAT,
      offset: uint32(offsetOf(Vertex, pos)),
    ),
    VkVertexInputAttributeDescription(
      location: 1,
      binding: 0,
      format: VK_FORMAT_R32G32_SFLOAT,
      offset: uint32(offsetOf(Vertex, uv)),
    ),
    VkVertexInputAttributeDescription(
      location: 2,
      binding: 0,
      format: VK_FORMAT_R8G8B8A8_UNORM,
      offset: uint32(offsetOf(Vertex, color)),
    ),
    VkVertexInputAttributeDescription(
      location: 3,
      binding: 0,
      format: VK_FORMAT_R8G8B8A8_UNORM,
      offset: uint32(offsetOf(Vertex, fillMidColor)),
    ),
    VkVertexInputAttributeDescription(
      location: 4,
      binding: 0,
      format: VK_FORMAT_R8G8B8A8_UNORM,
      offset: uint32(offsetOf(Vertex, fillStopColor)),
    ),
    VkVertexInputAttributeDescription(
      location: 5,
      binding: 0,
      format: VK_FORMAT_R32G32B32A32_SFLOAT,
      offset: uint32(offsetOf(Vertex, sdfParams)),
    ),
    VkVertexInputAttributeDescription(
      location: 6,
      binding: 0,
      format: VK_FORMAT_R32G32B32A32_SFLOAT,
      offset: uint32(offsetOf(Vertex, sdfRadii)),
    ),
    VkVertexInputAttributeDescription(
      location: 7,
      binding: 0,
      format: VK_FORMAT_R16_UINT,
      offset: uint32(offsetOf(Vertex, sdfMode)),
    ),
    VkVertexInputAttributeDescription(
      location: 8,
      binding: 0,
      format: VK_FORMAT_R32G32_SFLOAT,
      offset: uint32(offsetOf(Vertex, sdfFactors)),
    ),
    VkVertexInputAttributeDescription(
      location: 9,
      binding: 0,
      format: VK_FORMAT_R32G32B32A32_SFLOAT,
      offset: uint32(offsetOf(Vertex, rectMaskParams)),
    ),
    VkVertexInputAttributeDescription(
      location: 10,
      binding: 0,
      format: VK_FORMAT_R32G32B32A32_SFLOAT,
      offset: uint32(offsetOf(Vertex, rectMaskRadii)),
    ),
    VkVertexInputAttributeDescription(
      location: 11,
      binding: 0,
      format: VK_FORMAT_R32G32B32A32_SFLOAT,
      offset: uint32(offsetOf(Vertex, rectMaskMatX)),
    ),
    VkVertexInputAttributeDescription(
      location: 12,
      binding: 0,
      format: VK_FORMAT_R32G32B32A32_SFLOAT,
      offset: uint32(offsetOf(Vertex, rectMaskMatY)),
    ),
  ]

  let vertexInputInfo = newVkPipelineVertexInputStateCreateInfo(
    vertexBindingDescriptions = [bindingDesc], vertexAttributeDescriptions = attrDescs
  )

  let inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0.VkPipelineInputAssemblyStateCreateFlags,
    topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    primitiveRestartEnable: VkBool32(VkFalse),
  )

  let viewportState = VkPipelineViewportStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0.VkPipelineViewportStateCreateFlags,
    viewportCount: 1,
    pViewports: nil,
    scissorCount: 1,
    pScissors: nil,
  )

  let rasterizer = VkPipelineRasterizationStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0.VkPipelineRasterizationStateCreateFlags,
    depthClampEnable: VkBool32(VkFalse),
    rasterizerDiscardEnable: VkBool32(VkFalse),
    polygonMode: VK_POLYGON_MODE_FILL,
    cullMode: 0.VkCullModeFlags,
    frontFace: VK_FRONT_FACE_COUNTER_CLOCKWISE,
    depthBiasEnable: VkBool32(VkFalse),
    depthBiasConstantFactor: 0,
    depthBiasClamp: 0,
    depthBiasSlopeFactor: 0,
    lineWidth: 1.0,
  )

  let multisampling = VkPipelineMultisampleStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0.VkPipelineMultisampleStateCreateFlags,
    rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
    sampleShadingEnable: VkBool32(VkFalse),
    minSampleShading: 1.0,
    pSampleMask: nil,
    alphaToCoverageEnable: VkBool32(VkFalse),
    alphaToOneEnable: VkBool32(VkFalse),
  )

  let colorBlendAttachment = newVkPipelineColorBlendAttachmentState(
    blendEnable = VkBool32(VkTrue),
    srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA,
    dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
    colorBlendOp = VK_BLEND_OP_ADD,
    srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE,
    dstAlphaBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
    alphaBlendOp = VK_BLEND_OP_ADD,
    colorWriteMask = VkColorComponentFlags{RBit, GBit, BBit, ABit},
  )

  let colorBlending = VkPipelineColorBlendStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0.VkPipelineColorBlendStateCreateFlags,
    logicOpEnable: VkBool32(VkFalse),
    logicOp: VK_LOGIC_OP_COPY,
    attachmentCount: 1,
    pAttachments: colorBlendAttachment.unsafeAddr,
    blendConstants: [0.0'f32, 0.0'f32, 0.0'f32, 0.0'f32],
  )

  let dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]
  let dynamicState = VkPipelineDynamicStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0.VkPipelineDynamicStateCreateFlags,
    dynamicStateCount: dynamicStates.len.uint32,
    pDynamicStates: dynamicStates[0].unsafeAddr,
  )

  let pipelineLayoutInfo = newVkPipelineLayoutCreateInfo(
    setLayouts = [ctx.descriptorSetLayout], pushConstantRanges = []
  )
  ctx.pipelineLayout = createPipelineLayout(ctx.device, pipelineLayoutInfo)

  let pipelineInfo = newVkGraphicsPipelineCreateInfo(
    stages = [vertStage, fragStage],
    pVertexInputState = unsafeAddr vertexInputInfo,
    pInputAssemblyState = unsafeAddr inputAssembly,
    pTessellationState = nil,
    pViewportState = unsafeAddr viewportState,
    pRasterizationState = unsafeAddr rasterizer,
    pMultisampleState = unsafeAddr multisampling,
    pDepthStencilState = nil,
    pColorBlendState = unsafeAddr colorBlending,
    pDynamicState = unsafeAddr dynamicState,
    layout = ctx.pipelineLayout,
    renderPass = ctx.renderPass,
    subpass = 0,
    basePipelineHandle = 0.VkPipeline,
    basePipelineIndex = -1,
  )
  checkVkResult vkCreateGraphicsPipelines(
    ctx.device, 0.VkPipelineCache, 1, pipelineInfo.addr, nil, ctx.pipeline.addr
  )

proc createOffscreenTarget(ctx: VulkanContext, width, height: int32) =
  let pipelineNeedsRecreate =
    ctx.targetFormat != VK_FORMAT_R8G8B8A8_UNORM or ctx.renderPass == vkNullRenderPass or
    ctx.pipeline == vkNullPipeline or ctx.pipelineLayout == vkNullPipelineLayout or
    ctx.blurRenderPass == vkNullRenderPass or ctx.blurPipeline == vkNullPipeline or
    ctx.blurPipelineLayout == vkNullPipelineLayout

  ctx.destroyOffscreenTarget()

  ctx.targetFormat = VK_FORMAT_R8G8B8A8_UNORM
  ctx.targetExtent = VkExtent2D(width: width.uint32, height: height.uint32)

  # Create Pipeline first so we have the renderPass for the framebuffers
  if pipelineNeedsRecreate:
    ctx.createPipeline()
    ctx.createBlurPipeline()

  for i in 0 ..< 2:
    var extInfo = VkExternalMemoryImageCreateInfo(
      sType: ExternalMemoryImageCreateInfo,
      pNext: nil,
      handleTypes: VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT,
    )

    let imageInfo = newVkImageCreateInfo(
      pNext = addr extInfo,
      imageType = VK_IMAGE_TYPE_2D,
      format = ctx.targetFormat,
      extent = newVkExtent3D(width = width.uint32, height = height.uint32, depth = 1),
      mipLevels = 1,
      arrayLayers = 1,
      samples = VK_SAMPLE_COUNT_1_BIT,
      tiling = VK_IMAGE_TILING_LINEAR,
      usage = VkImageUsageFlags{ColorAttachmentBit, TransferSrcBit, SampledBit},
      sharingMode = VK_SHARING_MODE_EXCLUSIVE,
      queueFamilyIndices = [],
      initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
    )

    checkVkResult vkCreateImage(ctx.device, imageInfo.addr, nil, ctx.swapImages[i].addr)

    var req: VkMemoryRequirements
    vkGetImageMemoryRequirements(ctx.device, ctx.swapImages[i], req.addr)

    var exportInfo = VkExportMemoryAllocateInfo(
      sType: ExportMemoryAllocateInfo,
      pNext: nil,
      handleTypes: VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT,
    )

    let allocInfo = newVkMemoryAllocateInfo(
      pNext = addr exportInfo,
      allocationSize = req.size,
      memoryTypeIndex = findMemoryType(
        ctx.physicalDevice, req.memoryTypeBits, VkMemoryPropertyFlags{DeviceLocalBit}
      ),
    )

    checkVkResult vkAllocateMemory(
      ctx.device, allocInfo.addr, nil, ctx.swapMemories[i].addr
    )
    checkVkResult vkBindImageMemory(
      ctx.device, ctx.swapImages[i], ctx.swapMemories[i], 0.VkDeviceSize
    )

    var getFdInfo = VkMemoryGetFdInfoKHR(
      sType: MemoryGetFdInfoKHR,
      pNext: nil,
      memory: ctx.swapMemories[i],
      handleType: VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT,
    )
    var fd: cint = -1
    checkVkResult vkGetMemoryFdKHR_dyn(ctx.device, getFdInfo.addr, fd.addr)
    ctx.swapFds[i] = fd.int32

    ctx.swapViews[i] = ctx.createImageView(
      ctx.swapImages[i], ctx.targetFormat, VkImageAspectFlags{ColorBit}
    )

    let fbInfo = newVkFramebufferCreateInfo(
      renderPass = ctx.renderPass,
      attachments = [ctx.swapViews[i]],
      width = width.uint32,
      height = height.uint32,
      layers = 1,
    )
    checkVkResult vkCreateFramebuffer(
      ctx.device, fbInfo.addr, nil, ctx.swapFramebuffers[i].addr
    )

  ctx.targetRequestedWidth = width
  ctx.targetRequestedHeight = height

proc clearFrameVertexUploads(ctx: VulkanContext) =
  ctx.frameVertexBuffers.setLen(0)

proc ensureOffscreenTarget(ctx: VulkanContext, width, height: int32) =
  if width <= 0 or height <= 0:
    return

  let sizeChanged =
    ctx.targetRequestedWidth != width or ctx.targetRequestedHeight != height
  let needsRecreate = ctx.targetImage == vkNullImage or sizeChanged
  if not needsRecreate:
    return

  if ctx.device != vkNullDevice:
    discard vkDeviceWaitIdle(ctx.device)
    ctx.clearFrameVertexUploads()
  ctx.createOffscreenTarget(width, height)

proc ensureAtlasUploadBuffer(ctx: VulkanContext, bytes: VkDeviceSize) =
  if not ctx.atlasUploadBuffer.isNilOrEmpty and ctx.atlasUploadBytes >= bytes:
    return

  ctx.atlasUploadBuffer = nil

  let alloc = ctx.createBuffer(
    size = bytes,
    usage = VkBufferUsageFlags{TransferSrcBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.atlasUploadBuffer = alloc
  ctx.atlasUploadBytes = bytes

proc ensureReadbackBuffer(ctx: VulkanContext, bytes: VkDeviceSize) =
  if not ctx.readbackBuffer.isNilOrEmpty and ctx.readbackBytes >= bytes:
    return

  ctx.readbackBuffer = nil

  let alloc = ctx.createBuffer(
    size = bytes,
    usage = VkBufferUsageFlags{TransferDstBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.readbackBuffer = alloc
  ctx.readbackBytes = bytes

proc recordAtlasUpload(ctx: VulkanContext, cmd: VkCommandBuffer) =
  let bytes = VkDeviceSize(ctx.atlasSize * ctx.atlasSize * 4)
  ctx.ensureAtlasUploadBuffer(bytes)

  let mapped = cast[ptr uint8](mapMemory(
    ctx.device, ctx.atlasUploadBuffer.allocation, 0.VkDeviceSize, bytes,
    0.VkMemoryMapFlags,
  ))
  copyMem(mapped, ctx.atlasPixels.data[0].addr, int(bytes))
  unmapMemory(ctx.device, ctx.atlasUploadBuffer.allocation)

  let atlasOldLayout =
    if ctx.atlasLayoutReady:
      VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
    else:
      VK_IMAGE_LAYOUT_UNDEFINED
  let atlasSrcAccess =
    if ctx.atlasLayoutReady:
      VkAccessFlags{ShaderReadBit}
    else:
      0.VkAccessFlags
  let atlasSrcStage =
    if ctx.atlasLayoutReady:
      VkPipelineStageFlags{FragmentShaderBit}
    else:
      VkPipelineStageFlags{TopOfPipeBit}

  var barrierToTransfer = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: atlasSrcAccess,
    dstAccessMask: VkAccessFlags{TransferWriteBit},
    oldLayout: atlasOldLayout,
    newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.atlasImage.handle,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    cmd,
    atlasSrcStage,
    VkPipelineStageFlags{TransferBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    barrierToTransfer.addr,
  )

  var region = VkBufferImageCopy(
    bufferOffset: 0.VkDeviceSize,
    bufferRowLength: 0,
    bufferImageHeight: 0,
    imageSubresource: newVkImageSubresourceLayers(
      aspectMask = VkImageAspectFlags{ColorBit},
      mipLevel = 0,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
    imageOffset: newVkOffset3D(x = 0, y = 0, z = 0),
    imageExtent: newVkExtent3D(
      width = ctx.atlasSize.uint32, height = ctx.atlasSize.uint32, depth = 1
    ),
  )
  vkCmdCopyBufferToImage(
    cmd, ctx.atlasUploadBuffer.handle, ctx.atlasImage.handle,
    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, region.addr,
  )

  var barrierToRead = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: VkAccessFlags{TransferWriteBit},
    dstAccessMask: VkAccessFlags{ShaderReadBit},
    oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.atlasImage.handle,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    cmd,
    VkPipelineStageFlags{TransferBit},
    VkPipelineStageFlags{FragmentShaderBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    barrierToRead.addr,
  )

  ctx.atlasDirty = false
  ctx.atlasLayoutReady = true

proc recordSwapchainReadback(ctx: VulkanContext) =
  if ctx.targetImage == vkNullImage:
    return

  let width = int32(ctx.targetExtent.width)
  let height = int32(ctx.targetExtent.height)
  if width <= 0 or height <= 0:
    return

  let readbackBytes = VkDeviceSize(width * height * 4)
  ctx.ensureReadbackBuffer(readbackBytes)

  var imageToTransfer = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: VkAccessFlags{ColorAttachmentWriteBit},
    dstAccessMask: VkAccessFlags{TransferReadBit},
    oldLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    newLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.targetImage,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    ctx.commandBuffer,
    VkPipelineStageFlags{ColorAttachmentOutputBit},
    VkPipelineStageFlags{TransferBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    imageToTransfer.addr,
  )

  var copyRegion = VkBufferImageCopy(
    bufferOffset: 0.VkDeviceSize,
    bufferRowLength: 0,
    bufferImageHeight: 0,
    imageSubresource: newVkImageSubresourceLayers(
      aspectMask = VkImageAspectFlags{ColorBit},
      mipLevel = 0,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
    imageOffset: newVkOffset3D(x = 0, y = 0, z = 0),
    imageExtent: newVkExtent3D(
      width = ctx.targetExtent.width, height = ctx.targetExtent.height, depth = 1
    ),
  )
  vkCmdCopyImageToBuffer(
    ctx.commandBuffer, ctx.targetImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    ctx.readbackBuffer.handle, 1, copyRegion.addr,
  )

  var readbackBarrier = VkBufferMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: VkAccessFlags{TransferWriteBit},
    dstAccessMask: VkAccessFlags{HostReadBit},
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    buffer: ctx.readbackBuffer.handle,
    offset: 0.VkDeviceSize,
    size: readbackBytes,
  )
  vkCmdPipelineBarrier(
    ctx.commandBuffer,
    VkPipelineStageFlags{TransferBit},
    VkPipelineStageFlags{HostBit},
    0.VkDependencyFlags,
    0,
    nil,
    1,
    readbackBarrier.addr,
    0,
    nil,
  )

  var imageToPresent = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: VkAccessFlags{TransferReadBit},
    dstAccessMask: 0.VkAccessFlags,
    oldLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    newLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.targetImage,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    ctx.commandBuffer,
    VkPipelineStageFlags{TransferBit},
    VkPipelineStageFlags{BottomOfPipeBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    imageToPresent.addr,
  )

  ctx.readbackWidth = width
  ctx.readbackHeight = height
  ctx.readbackReady = true

proc createInstanceWithFallback(ctx: VulkanContext): VkInstance =
  let appInfo = newVkApplicationInfo(
    pApplicationName = "figdraw-vulkan",
    applicationVersion = vkMakeVersion(0, 0, 1, 0),
    pEngineName = "figdraw",
    engineVersion = vkMakeVersion(0, 0, 1, 0),
    apiVersion = vkApiVersion1_1,
  )
  let instanceInfo = newVkInstanceCreateInfo(
    pApplicationInfo = appInfo.addr,
    pEnabledLayerNames = [],
    pEnabledExtensionNames = [],
  )
  try:
    return createInstance(instanceInfo)
  except VulkanError as exc:
    raise

proc applyClipScissor(ctx: VulkanContext) =
  if not ctx.commandRecording or ctx.targetImage == vkNullImage or
      not ctx.renderPassBegun:
    return

  let clipRect =
    if ctx.clipRects.len > 0:
      ctx.clipRects[^1]
    else:
      ctx.fullFrameRect()

  let maxW = max(0'i32, ctx.targetExtent.width.int32)
  let maxH = max(0'i32, ctx.targetExtent.height.int32)

  var x0 = clamp(floor(clipRect.x).int32, 0'i32, maxW)
  var y0 = clamp(floor(clipRect.y).int32, 0'i32, maxH)
  var x1 = clamp(ceil(clipRect.x + clipRect.w).int32, 0'i32, maxW)
  var y1 = clamp(ceil(clipRect.y + clipRect.h).int32, 0'i32, maxH)
  if x1 < x0:
    x1 = x0
  if y1 < y0:
    y1 = y0

  var scissor = newVkRect2D(
    offset = newVkOffset2D(x = x0, y = y0),
    extent = newVkExtent2D(width = uint32(x1 - x0), height = uint32(y1 - y0)),
  )
  vkCmdSetScissor(ctx.commandBuffer, 0, 1, scissor.addr)

proc beginRenderPassIfNeeded(ctx: VulkanContext) =
  if not ctx.commandRecording or ctx.targetImage == vkNullImage or ctx.renderPassBegun:
    return

  let renderPassInfo = VkRenderPassBeginInfo(
    sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
    pNext: nil,
    renderPass: ctx.renderPass,
    framebuffer: ctx.targetFramebuffer,
    renderArea:
      newVkRect2D(offset = newVkOffset2D(x = 0, y = 0), extent = ctx.targetExtent),
    clearValueCount: 0,
    pClearValues: nil,
  )
  vkCmdBeginRenderPass(
    ctx.commandBuffer, renderPassInfo.addr, VK_SUBPASS_CONTENTS_INLINE
  )
  ctx.renderPassBegun = true

  let viewport = newVkViewport(
    x = 0,
    y = 0,
    width = ctx.targetExtent.width.float32,
    height = ctx.targetExtent.height.float32,
    minDepth = 0,
    maxDepth = 1,
  )
  vkCmdSetViewport(ctx.commandBuffer, 0, 1, viewport.addr)

  var fullScissor =
    newVkRect2D(offset = newVkOffset2D(x = 0, y = 0), extent = ctx.targetExtent)
  vkCmdSetScissor(ctx.commandBuffer, 0, 1, fullScissor.addr)

  if ctx.frameNeedsClear:
    let clearValue = VkClearValue(
      color: VkClearColorValue(
        float32: [
          ctx.frameClearColor.r.float32, ctx.frameClearColor.g.float32,
          ctx.frameClearColor.b.float32, ctx.frameClearColor.a.float32,
        ]
      )
    )
    var clearAttachment = VkClearAttachment(
      aspectMask: VkImageAspectFlags{ColorBit},
      colorAttachment: 0,
      clearValue: clearValue,
    )
    var clearRect = VkClearRect(
      rect: newVkRect2D(offset = newVkOffset2D(x = 0, y = 0), extent = ctx.targetExtent),
      baseArrayLayer: 0,
      layerCount: 1,
    )
    vkCmdClearAttachments(ctx.commandBuffer, 1, clearAttachment.addr, 1, clearRect.addr)
    ctx.frameNeedsClear = false

  if ctx.clipRects.len > 0:
    ctx.applyClipScissor()

proc ensureGpuRuntime*(ctx: VulkanContext) =
  if ctx.gpuReady:
    return

  vkPreload()
  if ctx.instance == vkNullInstance:
    ctx.instance = ctx.createInstanceWithFallback()
    vkInit(ctx.instance, load1_2 = false, load1_3 = false)

  let devices = enumeratePhysicalDevices(ctx.instance)
  if devices.len == 0:
    raise newException(ValueError, "No Vulkan physical devices found")

  var selectedQueues: QueueFamilyIndices
  for device in devices:
    let queues = findQueueFamilies(device, vkNullSurface, requirePresent = false)
    if not queues.graphicsFound:
      continue
    ctx.physicalDevice = device
    selectedQueues = queues
    break

  if ctx.physicalDevice == vkNullPhysicalDevice:
    raise newException(ValueError, "No suitable Vulkan physical device found")

  ctx.driverInfo = queryVulkanDriverInfo(ctx.physicalDevice)
  ctx.queueFamily = selectedQueues.graphicsFamily

  var queueCreateInfos = @[
    newVkDeviceQueueCreateInfo(
      queueFamilyIndex = ctx.queueFamily, queuePriorities = [1.0'f32]
    )
  ]

  let deviceExtensions = @[
    "VK_KHR_external_memory".cstring, "VK_KHR_external_memory_fd".cstring,
    "VK_EXT_external_memory_dma_buf".cstring, "VK_EXT_image_drm_format_modifier".cstring,
  ]

  let deviceInfo = newVkDeviceCreateInfo(
    queueCreateInfos = queueCreateInfos,
    pEnabledLayerNames = [],
    pEnabledExtensionNames = deviceExtensions,
    enabledFeatures = [],
  )
  ctx.device = createDevice(ctx.physicalDevice, deviceInfo)
  ctx.queue = getDeviceQueue(ctx.device, ctx.queueFamily, 0)

  vkGetMemoryFdKHR_dyn = cast[proc(
    device: VkDevice, pGetFdInfo: ptr VkMemoryGetFdInfoKHR, pFd: ptr cint
  ): VkResult {.stdcall.}](vkGetDeviceProcAddr(ctx.device, "vkGetMemoryFdKHR"))

  let poolInfo = newVkCommandPoolCreateInfo(
    queueFamilyIndex = ctx.queueFamily,
    flags = VkCommandPoolCreateFlags{ResetCommandBufferBit},
  )
  ctx.commandPool = createCommandPool(ctx.device, poolInfo)

  # --- SWAPCHAIN FIX: Allocate 2 Command Buffers ---
  let cmdAlloc = newVkCommandBufferAllocateInfo(
    commandPool = ctx.commandPool,
    level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    commandBufferCount = 2,
  )
  checkVkResult vkAllocateCommandBuffers(
    ctx.device, cmdAlloc.addr, ctx.swapCommandBuffers[0].addr
  )

  # --- SWAPCHAIN FIX: Allocate 2 Semaphores and 2 Fences ---
  let semaphoreInfo = newVkSemaphoreCreateInfo()
  let fenceInfo = newVkFenceCreateInfo(flags = VkFenceCreateFlags{SignaledBit})

  for i in 0 ..< 2:
    checkVkResult vkCreateSemaphore(
      ctx.device, semaphoreInfo.addr, nil, ctx.swapSemaphores[i].addr
    )
    checkVkResult vkCreateFence(ctx.device, fenceInfo.addr, nil, ctx.swapFences[i].addr)

  let setBindings = [
    newVkDescriptorSetLayoutBinding(
      binding = 0,
      descriptorType = VkDescriptorType.UniformBuffer,
      descriptorCount = 1,
      stageFlags = VkShaderStageFlags{VertexBit},
      pImmutableSamplers = nil,
    ),
    newVkDescriptorSetLayoutBinding(
      binding = 1,
      descriptorType = VkDescriptorType.UniformBuffer,
      descriptorCount = 1,
      stageFlags = VkShaderStageFlags{FragmentBit},
      pImmutableSamplers = nil,
    ),
    newVkDescriptorSetLayoutBinding(
      binding = 2,
      descriptorType = VkDescriptorType.CombinedImageSampler,
      descriptorCount = 1,
      stageFlags = VkShaderStageFlags{FragmentBit},
      pImmutableSamplers = nil,
    ),
    newVkDescriptorSetLayoutBinding(
      binding = 3,
      descriptorType = VkDescriptorType.CombinedImageSampler,
      descriptorCount = 1,
      stageFlags = VkShaderStageFlags{FragmentBit},
      pImmutableSamplers = nil,
    ),
    newVkDescriptorSetLayoutBinding(
      binding = 4,
      descriptorType = VkDescriptorType.CombinedImageSampler,
      descriptorCount = 1,
      stageFlags = VkShaderStageFlags{FragmentBit},
      pImmutableSamplers = nil,
    ),
  ]
  ctx.descriptorSetLayout = createDescriptorSetLayout(
    ctx.device, newVkDescriptorSetLayoutCreateInfo(bindings = setBindings)
  )

  let poolSizes = [
    newVkDescriptorPoolSize(
      `type` = VkDescriptorType.UniformBuffer, descriptorCount = 2
    ),
    newVkDescriptorPoolSize(
      `type` = VkDescriptorType.CombinedImageSampler, descriptorCount = 3
    ),
  ]
  ctx.descriptorPool = createDescriptorPool(
    ctx.device, newVkDescriptorPoolCreateInfo(maxSets = 1, poolSizes = poolSizes)
  )
  ctx.descriptorSet = allocateDescriptorSets(
    ctx.device,
    newVkDescriptorSetAllocateInfo(
      descriptorPool = ctx.descriptorPool, setLayouts = [ctx.descriptorSetLayout]
    ),
  )

  let blurSetBindings = [
    newVkDescriptorSetLayoutBinding(
      binding = 0,
      descriptorType = VkDescriptorType.CombinedImageSampler,
      descriptorCount = 1,
      stageFlags = VkShaderStageFlags{FragmentBit},
      pImmutableSamplers = nil,
    ),
    newVkDescriptorSetLayoutBinding(
      binding = 1,
      descriptorType = VkDescriptorType.UniformBuffer,
      descriptorCount = 1,
      stageFlags = VkShaderStageFlags{FragmentBit},
      pImmutableSamplers = nil,
    ),
  ]
  ctx.blurDescriptorSetLayout = createDescriptorSetLayout(
    ctx.device, newVkDescriptorSetLayoutCreateInfo(bindings = blurSetBindings)
  )

  let blurPoolSizes = [
    newVkDescriptorPoolSize(
      `type` = VkDescriptorType.CombinedImageSampler, descriptorCount = 2
    ),
    newVkDescriptorPoolSize(
      `type` = VkDescriptorType.UniformBuffer, descriptorCount = 2
    ),
  ]
  ctx.blurDescriptorPool = createDescriptorPool(
    ctx.device, newVkDescriptorPoolCreateInfo(maxSets = 2, poolSizes = blurPoolSizes)
  )
  ctx.blurDescriptorSets[0] = allocateDescriptorSets(
    ctx.device,
    newVkDescriptorSetAllocateInfo(
      descriptorPool = ctx.blurDescriptorPool,
      setLayouts = [ctx.blurDescriptorSetLayout],
    ),
  )
  ctx.blurDescriptorSets[1] = allocateDescriptorSets(
    ctx.device,
    newVkDescriptorSetAllocateInfo(
      descriptorPool = ctx.blurDescriptorPool,
      setLayouts = [ctx.blurDescriptorSetLayout],
    ),
  )

  let vertexBytes = VkDeviceSize(sizeof(Vertex) * ctx.maxQuads * 4)
  let vertexAlloc = ctx.createBuffer(
    size = vertexBytes,
    usage = VkBufferUsageFlags{VertexBufferBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.vertexBuffer = vertexAlloc
  ctx.vertexBufferBytes = vertexBytes

  let indexBytes = VkDeviceSize(sizeof(uint16) * ctx.indices.len)
  let indexAlloc = ctx.createBuffer(
    size = indexBytes,
    usage = VkBufferUsageFlags{IndexBufferBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.indexBuffer = indexAlloc
  ctx.indexBufferBytes = indexBytes

  let mappedIdx = cast[ptr uint8](mapMemory(
    ctx.device, ctx.indexBuffer.allocation, 0.VkDeviceSize, indexBytes,
    0.VkMemoryMapFlags,
  ))
  copyMem(mappedIdx, ctx.indices[0].addr, int(indexBytes))
  unmapMemory(ctx.device, ctx.indexBuffer.allocation)

  let vsAlloc = ctx.createBuffer(
    size = VkDeviceSize(sizeof(VSUniforms)),
    usage = VkBufferUsageFlags{UniformBufferBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.vsUniformBuffer = vsAlloc

  let fsAlloc = ctx.createBuffer(
    size = VkDeviceSize(sizeof(FSUniforms)),
    usage = VkBufferUsageFlags{UniformBufferBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.fsUniformBuffer = fsAlloc

  let blurAlloc0 = ctx.createBuffer(
    size = VkDeviceSize(sizeof(BlurUniforms)),
    usage = VkBufferUsageFlags{UniformBufferBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.blurUniformBuffers[0] = blurAlloc0
  let blurAlloc1 = ctx.createBuffer(
    size = VkDeviceSize(sizeof(BlurUniforms)),
    usage = VkBufferUsageFlags{UniformBufferBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.blurUniformBuffers[1] = blurAlloc1

  let samplerInfo = newVkSamplerCreateInfo(
    magFilter = VK_FILTER_LINEAR,
    minFilter = VK_FILTER_LINEAR,
    mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR,
    addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
    mipLodBias = 0,
    anisotropyEnable = VkBool32(VkFalse),
    maxAnisotropy = 1,
    compareEnable = VkBool32(VkFalse),
    compareOp = VK_COMPARE_OP_ALWAYS,
    minLod = 0,
    maxLod = 0,
    borderColor = VK_BORDER_COLOR_INT_OPAQUE_BLACK,
    unnormalizedCoordinates = VkBool32(VkFalse),
  )
  checkVkResult vkCreateSampler(
    ctx.device, samplerInfo.addr, nil, ctx.atlasSampler.addr
  )

  ctx.recreateAtlasGpu()
  ctx.updateDescriptorSet()
  ctx.updateBlurDescriptorSets()

  ctx.gpuReady = true

proc flush(ctx: VulkanContext) =
  if ctx.quadCount == 0:
    return
  if not ctx.commandRecording:
    ctx.quadCount = 0
    ctx.batchHasRectMask = false
    return
  if ctx.atlasDirty:
    if ctx.renderPassBegun:
      vkCmdEndRenderPass(ctx.commandBuffer)
      ctx.renderPassBegun = false
    ctx.recordAtlasUpload(ctx.commandBuffer)
  ctx.beginRenderPassIfNeeded()

  let vertexCount = ctx.quadCount * 4
  for i in 0 ..< vertexCount:
    let v = addr ctx.vertexScratch[i]
    v.pos[0] = ctx.positions[i * 2 + 0]
    v.pos[1] = ctx.positions[i * 2 + 1]
    v.uv[0] = ctx.uvs[i * 2 + 0]
    v.uv[1] = ctx.uvs[i * 2 + 1]
    v.color[0] = ctx.colors[i * 4 + 0]
    v.color[1] = ctx.colors[i * 4 + 1]
    v.color[2] = ctx.colors[i * 4 + 2]
    v.color[3] = ctx.colors[i * 4 + 3]
    v.fillMidColor[0] = ctx.fillMidColors[i * 4 + 0]
    v.fillMidColor[1] = ctx.fillMidColors[i * 4 + 1]
    v.fillMidColor[2] = ctx.fillMidColors[i * 4 + 2]
    v.fillMidColor[3] = ctx.fillMidColors[i * 4 + 3]
    v.fillStopColor[0] = ctx.fillStopColors[i * 4 + 0]
    v.fillStopColor[1] = ctx.fillStopColors[i * 4 + 1]
    v.fillStopColor[2] = ctx.fillStopColors[i * 4 + 2]
    v.fillStopColor[3] = ctx.fillStopColors[i * 4 + 3]
    v.sdfParams[0] = ctx.sdfParams[i * 4 + 0]
    v.sdfParams[1] = ctx.sdfParams[i * 4 + 1]
    v.sdfParams[2] = ctx.sdfParams[i * 4 + 2]
    v.sdfParams[3] = ctx.sdfParams[i * 4 + 3]
    v.sdfRadii[0] = ctx.sdfRadii[i * 4 + 0]
    v.sdfRadii[1] = ctx.sdfRadii[i * 4 + 1]
    v.sdfRadii[2] = ctx.sdfRadii[i * 4 + 2]
    v.sdfRadii[3] = ctx.sdfRadii[i * 4 + 3]
    when defined(emscripten):
      v.sdfMode = uint16(ctx.sdfModeAttr[i])
    else:
      v.sdfMode = ctx.sdfModeAttr[i].uint16
    v.sdfPad = 0'u16
    v.sdfFactors[0] = ctx.sdfFactors[i * 2 + 0]
    v.sdfFactors[1] = ctx.sdfFactors[i * 2 + 1]
    if ctx.batchHasRectMask:
      v.rectMaskParams[0] = ctx.rectMaskParams[i * 4 + 0]
      v.rectMaskParams[1] = ctx.rectMaskParams[i * 4 + 1]
      v.rectMaskParams[2] = ctx.rectMaskParams[i * 4 + 2]
      v.rectMaskParams[3] = ctx.rectMaskParams[i * 4 + 3]
      v.rectMaskRadii[0] = ctx.rectMaskRadii[i * 4 + 0]
      v.rectMaskRadii[1] = ctx.rectMaskRadii[i * 4 + 1]
      v.rectMaskRadii[2] = ctx.rectMaskRadii[i * 4 + 2]
      v.rectMaskRadii[3] = ctx.rectMaskRadii[i * 4 + 3]
      v.rectMaskMatX[0] = ctx.rectMaskMatX[i * 4 + 0]
      v.rectMaskMatX[1] = ctx.rectMaskMatX[i * 4 + 1]
      v.rectMaskMatX[2] = ctx.rectMaskMatX[i * 4 + 2]
      v.rectMaskMatX[3] = ctx.rectMaskMatX[i * 4 + 3]
      v.rectMaskMatY[0] = ctx.rectMaskMatY[i * 4 + 0]
      v.rectMaskMatY[1] = ctx.rectMaskMatY[i * 4 + 1]
      v.rectMaskMatY[2] = ctx.rectMaskMatY[i * 4 + 2]
      v.rectMaskMatY[3] = ctx.rectMaskMatY[i * 4 + 3]
    else:
      v.rectMaskParams[0] = 0.0'f32
      v.rectMaskParams[1] = 0.0'f32
      v.rectMaskParams[2] = -1.0'f32
      v.rectMaskParams[3] = -1.0'f32
      v.rectMaskRadii[0] = 0.0'f32
      v.rectMaskRadii[1] = 0.0'f32
      v.rectMaskRadii[2] = 0.0'f32
      v.rectMaskRadii[3] = 0.0'f32
      v.rectMaskMatX[0] = 0.0'f32
      v.rectMaskMatX[1] = 0.0'f32
      v.rectMaskMatX[2] = 0.0'f32
      v.rectMaskMatX[3] = 0.0'f32
      v.rectMaskMatY[0] = 0.0'f32
      v.rectMaskMatY[1] = 0.0'f32
      v.rectMaskMatY[2] = 0.0'f32
      v.rectMaskMatY[3] = 0.0'f32

  let uploadBytes = VkDeviceSize(vertexCount * sizeof(Vertex))
  let vertexAlloc = ctx.createBuffer(
    size = uploadBytes,
    usage = VkBufferUsageFlags{VertexBufferBit},
    properties = VkMemoryPropertyFlags{HostVisibleBit, HostCoherentBit},
  )
  ctx.frameVertexBuffers.add(vertexAlloc)

  let mappedVertex = cast[ptr uint8](mapMemory(
    ctx.device, vertexAlloc.allocation, 0.VkDeviceSize, uploadBytes, 0.VkMemoryMapFlags
  ))
  copyMem(mappedVertex, ctx.vertexScratch[0].addr, int(uploadBytes))
  unmapMemory(ctx.device, vertexAlloc.allocation)

  var vsu = VSUniforms(proj: ctx.proj)
  var fsu = FSUniforms(
    windowFrame: ctx.frameSize, aaFactor: ctx.aaFactor, maskTexEnabled: 0'u32
  )

  let mappedVs = cast[ptr uint8](mapMemory(
    ctx.device,
    ctx.vsUniformBuffer.allocation,
    0.VkDeviceSize,
    VkDeviceSize(sizeof(VSUniforms)),
    0.VkMemoryMapFlags,
  ))
  copyMem(mappedVs, vsu.addr, sizeof(VSUniforms))
  unmapMemory(ctx.device, ctx.vsUniformBuffer.allocation)

  let mappedFs = cast[ptr uint8](mapMemory(
    ctx.device,
    ctx.fsUniformBuffer.allocation,
    0.VkDeviceSize,
    VkDeviceSize(sizeof(FSUniforms)),
    0.VkMemoryMapFlags,
  ))
  copyMem(mappedFs, fsu.addr, sizeof(FSUniforms))
  unmapMemory(ctx.device, ctx.fsUniformBuffer.allocation)

  vkCmdBindPipeline(ctx.commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, ctx.pipeline)

  let vbs = [vertexAlloc.handle]
  let offs = [0.VkDeviceSize]
  vkCmdBindVertexBuffers(ctx.commandBuffer, 0, 1, vbs[0].unsafeAddr, offs[0].unsafeAddr)
  vkCmdBindIndexBuffer(
    ctx.commandBuffer, ctx.indexBuffer.handle, 0.VkDeviceSize, VK_INDEX_TYPE_UINT16
  )
  vkCmdBindDescriptorSets(
    ctx.commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, ctx.pipelineLayout, 0, 1,
    ctx.descriptorSet.addr, 0, nil,
  )

  let indexCount = uint32(ctx.quadCount * 6)
  vkCmdDrawIndexed(ctx.commandBuffer, indexCount, 1, 0, 0, 0)
  ctx.quadCount = 0
  ctx.batchHasRectMask = false

proc checkBatch(ctx: VulkanContext) =
  if not ctx.commandRecording:
    ctx.quadCount = 0
    ctx.batchHasRectMask = false
    return
  if ctx.quadCount >= ctx.maxQuads:
    ctx.flush()

proc setVert2(buf: var seq[float32], i: int, v: Vec2) =
  buf[i * 2 + 0] = v.x
  buf[i * 2 + 1] = v.y

proc setVert4(buf: var seq[float32], i: int, v: Vec4) =
  buf[i * 4 + 0] = v.x
  buf[i * 4 + 1] = v.y
  buf[i * 4 + 2] = v.z
  buf[i * 4 + 3] = v.w

proc setVertColor(buf: var seq[uint8], i: int, color: ColorRGBA) =
  buf[i * 4 + 0] = color.r
  buf[i * 4 + 1] = color.g
  buf[i * 4 + 2] = color.b
  buf[i * 4 + 3] = color.a

proc setFillExtraColors(
    ctx: VulkanContext, offset: int, midColor, stopColor: ColorRGBA
) =
  ctx.fillMidColors.setVertColor(offset + 0, midColor)
  ctx.fillMidColors.setVertColor(offset + 1, midColor)
  ctx.fillMidColors.setVertColor(offset + 2, midColor)
  ctx.fillMidColors.setVertColor(offset + 3, midColor)
  ctx.fillStopColors.setVertColor(offset + 0, stopColor)
  ctx.fillStopColors.setVertColor(offset + 1, stopColor)
  ctx.fillStopColors.setVertColor(offset + 2, stopColor)
  ctx.fillStopColors.setVertColor(offset + 3, stopColor)

func roundedRadiiVec(radii: array[DirectionCorners, float32], halfExtents: Vec2): Vec4 =
  let maxRadius = min(halfExtents.x, halfExtents.y)
  let radiiClamped = [
    dcTopLeft: (
      if radii[dcTopLeft] <= 0.0'f32: 0.0'f32
      else: max(1.0'f32, min(radii[dcTopLeft], maxRadius)).round()
    ),
    dcTopRight: (
      if radii[dcTopRight] <= 0.0'f32: 0.0'f32
      else: max(1.0'f32, min(radii[dcTopRight], maxRadius)).round()
    ),
    dcBottomLeft: (
      if radii[dcBottomLeft] <= 0.0'f32: 0.0'f32
      else: max(1.0'f32, min(radii[dcBottomLeft], maxRadius)).round()
    ),
    dcBottomRight: (
      if radii[dcBottomRight] <= 0.0'f32: 0.0'f32
      else: max(1.0'f32, min(radii[dcBottomRight], maxRadius)).round()
    ),
  ]
  vec4(
    radiiClamped[dcTopRight],
    radiiClamped[dcBottomRight],
    radiiClamped[dcTopLeft],
    radiiClamped[dcBottomLeft],
  )

const
  SdfEllipseFlag = 128
  SdfRadiusQuantization = 4095.0'f32
  SdfRadiusQuantizationBase = 4096.0'f32
  SdfFillSolidOrVertex = 0
  SdfFillLinear3X = 1
  SdfFillLinear3Y = 2
  SdfFillLinear3DiagTLBR = 3
  SdfFillLinear3DiagBLTR = 4
  SdfFillModeShift = 256

func roundedRadius(radius, maximum: float32): float32 =
  if radius <= 0.0'f32:
    0.0'f32
  else:
    max(1.0'f32, min(radius, maximum)).round()

func packEllipticalRadius(rx, ry: float32, halfExtents: Vec2): float32 =
  let
    qx = round(
      clamp(rx / max(halfExtents.x, 0.000001'f32), 0.0'f32, 1.0'f32) *
        SdfRadiusQuantization
    )
    qy = round(
      clamp(ry / max(halfExtents.y, 0.000001'f32), 0.0'f32, 1.0'f32) *
        SdfRadiusQuantization
    )
  qx + qy * SdfRadiusQuantizationBase

func packCircularRadius(radius: float32): float32 =
  -(radius + 1.0'f32)

func roundedRadiiVec(
    radii: CornerRadii2D[float32], halfExtents: Vec2
): tuple[radii: Vec4, elliptical: bool] =
  var allCircular = true
  for corner in DirectionCorners:
    if radii.x[corner] != radii.y[corner]:
      allCircular = false

  if allCircular:
    return (roundedRadiiVec(radii.x, halfExtents), false)

  let radiiX = [
    dcTopLeft: roundedRadius(radii.x[dcTopLeft], halfExtents.x),
    dcTopRight: roundedRadius(radii.x[dcTopRight], halfExtents.x),
    dcBottomLeft: roundedRadius(radii.x[dcBottomLeft], halfExtents.x),
    dcBottomRight: roundedRadius(radii.x[dcBottomRight], halfExtents.x),
  ]
  let radiiY = [
    dcTopLeft: roundedRadius(radii.y[dcTopLeft], halfExtents.y),
    dcTopRight: roundedRadius(radii.y[dcTopRight], halfExtents.y),
    dcBottomLeft: roundedRadius(radii.y[dcBottomLeft], halfExtents.y),
    dcBottomRight: roundedRadius(radii.y[dcBottomRight], halfExtents.y),
  ]
  let circleMaxRadius = min(halfExtents.x, halfExtents.y)
  func encodeCorner(corner: DirectionCorners): float32 =
    let
      sameInputAxes = radii.x[corner] == radii.y[corner]
      circleRadius = roundedRadius(radii.x[corner], circleMaxRadius)
    if sameInputAxes:
      return packCircularRadius(circleRadius)
    if radiiX[corner] == radiiY[corner]:
      return packCircularRadius(radiiX[corner])
    packEllipticalRadius(radiiX[corner], radiiY[corner], halfExtents)
  (
    vec4(
      encodeCorner(dcTopRight),
      encodeCorner(dcBottomRight),
      encodeCorner(dcTopLeft),
      encodeCorner(dcBottomLeft),
    ),
    true,
  )

func linear3FillMode(axis: FillGradientAxis): int =
  case axis
  of fgaX: SdfFillLinear3X
  of fgaY: SdfFillLinear3Y
  of fgaDiagTLBR: SdfFillLinear3DiagTLBR
  of fgaDiagBLTR: SdfFillLinear3DiagBLTR

func encodeSdfMode(
    mode: SdfMode, fillMode: int, elliptical: bool = false
): SdfModeData =
  let packed =
    mode.int + (if elliptical: SdfEllipseFlag else: 0) + fillMode * SdfFillModeShift
  when SdfModeData is float32: packed.float32 else: packed.uint16

proc activeTextSubpixelShift(ctx: VulkanContext): float32 =
  if not ctx.textSubpixelPositioningEnabled:
    return 0.0'f32
  max(0.0'f32, min(ctx.textSubpixelShift, 0.999'f32))

func `*`*(m: Mat4, v: Vec2): Vec2 =
  (m * vec3(v.x, v.y, 0.0)).xy

proc makeRectMask(
    ctx: VulkanContext, maskRect: Rect, radii: CornerRadii2D[float32]
): RectMask =
  let
    halfExtents = maskRect.wh * 0.5'f32
    center = maskRect.xy + halfExtents
    invMat = ctx.mat.inverse()
    encodedRadii = roundedRadiiVec(radii, halfExtents)
  RectMask(
    kind: rmkFast,
    params: vec4(center.x, center.y, halfExtents.x, halfExtents.y),
    radii: encodedRadii.radii,
    matX: vec4(invMat[0, 0], invMat[1, 0], invMat[3, 0], 1.0'f32),
    matY: vec4(
      invMat[0, 1],
      invMat[1, 1],
      invMat[3, 1],
      if encodedRadii.elliptical: 1.0'f32 else: 0.0'f32,
    ),
  )

proc setRectMaskVert4(
    ctx: VulkanContext, offset: int, params, radii, matX, matY: Vec4
) =
  for i in 0 ..< 4:
    ctx.rectMaskParams.setVert4(offset + i, params)
    ctx.rectMaskRadii.setVert4(offset + i, radii)
    ctx.rectMaskMatX.setVert4(offset + i, matX)
    ctx.rectMaskMatY.setVert4(offset + i, matY)

proc setDisabledRectMaskVerts(ctx: VulkanContext, firstVertex, vertexCount: int) =
  let
    params = vec4(0.0'f32, 0.0'f32, -1.0'f32, -1.0'f32)
    zero4 = vec4(0.0'f32)
  for i in firstVertex ..< firstVertex + vertexCount:
    ctx.rectMaskParams.setVert4(i, params)
    ctx.rectMaskRadii.setVert4(i, zero4)
    ctx.rectMaskMatX.setVert4(i, zero4)
    ctx.rectMaskMatY.setVert4(i, zero4)

proc setRectMaskVert4(ctx: VulkanContext, offset: int) =
  if ctx.maskBegun:
    return

  var
    hasRectMask = false
    params = vec4(0.0'f32)
    radii = vec4(0.0'f32)
    matX = vec4(0.0'f32)
    matY = vec4(0.0'f32)

  if ctx.rectMaskStack.len > 0:
    for i in countdown(ctx.rectMaskStack.len - 1, 0):
      let rectMask = ctx.rectMaskStack[i]
      if rectMask.kind == rmkFast:
        hasRectMask = true
        params = rectMask.params
        radii = rectMask.radii
        matX = rectMask.matX
        matY = rectMask.matY
        break

  if hasRectMask:
    if not ctx.batchHasRectMask:
      ctx.setDisabledRectMaskVerts(0, offset)
      ctx.batchHasRectMask = true
    ctx.setRectMaskVert4(offset, params, radii, matX, matY)
  elif ctx.batchHasRectMask:
    ctx.setDisabledRectMaskVerts(offset, 4)

template setRectMaskVert4IfNeeded(ctx: VulkanContext, offset: int) =
  if not ctx.maskBegun and (ctx.batchHasRectMask or ctx.rectMaskStack.len > 0):
    ctx.setRectMaskVert4(offset)

proc copyIntoAtlas(atlas: Image, atX, atY: int, image: Image) =
  for y in 0 ..< image.height:
    let dstRow = (atY + y) * atlas.width + atX
    let srcRow = y * image.width
    copyMem(
      atlas.data[dstRow].addr,
      image.data[srcRow].unsafeAddr,
      image.width * sizeof(ColorRGBA),
    )

proc grow(ctx: VulkanContext) =
  let nextSize = ctx.atlasSize * 2
  ctx.resetImageAtlas(nextSize)

proc findEmptyRect(ctx: VulkanContext, width, height: int): Rect =
  let imgWidth = width + ctx.atlasMargin * 2
  let imgHeight = height + ctx.atlasMargin * 2

  var lowest = ctx.atlasSize
  var at = 0
  for i in 0 .. ctx.atlasSize - 1:
    let v = int(ctx.heights[i])
    if v < lowest:
      var fit = true
      for j in 0 .. imgWidth:
        if i + j >= ctx.atlasSize:
          fit = false
          break
        if int(ctx.heights[i + j]) > v:
          fit = false
          break
      if fit:
        lowest = v
        at = i

  if lowest + imgHeight > ctx.atlasSize:
    ctx.grow()
    return ctx.findEmptyRect(width, height)

  for j in at .. at + imgWidth - 1:
    ctx.heights[j] = uint16(lowest + imgHeight + ctx.atlasMargin * 2)

  rect(
    float32(at + ctx.atlasMargin),
    float32(lowest + ctx.atlasMargin),
    float32(width),
    float32(height),
  )

method putImage*(ctx: VulkanContext, path: Hash, image: Image)

method addImage*(ctx: VulkanContext, key: Hash, image: Image) =
  ctx.putImage(key, image)

method putImage*(ctx: VulkanContext, path: Hash, image: Image) =
  let rect = ctx.findEmptyRect(image.width, image.height)
  ctx.entries[path] = rect / float(ctx.atlasSize)
  ctx.markGeneratedEntry(path)
  copyIntoAtlas(ctx.atlasPixels, int(rect.x), int(rect.y), image)
  ctx.atlasDirty = true

method updateImage*(ctx: VulkanContext, path: Hash, image: Image) =
  let rect = ctx.entries[path]
  copyIntoAtlas(
    ctx.atlasPixels,
    int(rect.x * ctx.atlasSize.float),
    int(rect.y * ctx.atlasSize.float),
    image,
  )
  ctx.atlasDirty = true

proc putFlippy*(ctx: VulkanContext, path: Hash, flippy: Flippy) =
  if flippy.mipmaps.len == 0:
    return
  ctx.putImage(path, flippy.mipmaps[0])

method putImage*(ctx: VulkanContext, imgObj: ImgObj) =
  case imgObj.kind
  of FlippyImg:
    ctx.putFlippy(imgObj.id.Hash, imgObj.flippy)
  of PixieImg:
    ctx.putImage(imgObj.id.Hash, imgObj.pimg)
  ctx.markImageEntry(imgObj.id)

method clearImageAtlas*(ctx: VulkanContext) =
  ctx.resetImageAtlas(ctx.initialAtlasSize)

method resetImageAtlas*(ctx: VulkanContext, minimumSize: int) =
  ctx.flush()
  ctx.atlasSize = plannedAtlasSize(ctx.initialAtlasSize, minimumSize)
  ctx.entries.clear()
  ctx.atlasEntryMeta.clear()
  ctx.heights = newSeq[uint16](ctx.atlasSize)
  ctx.atlasPixels = newImage(ctx.atlasSize, ctx.atlasSize)
  ctx.atlasPixels.fill(rgba(0, 0, 0, 0))
  ctx.atlasDirty = true
  ctx.atlasLayoutReady = false
  if ctx.gpuReady:
    ctx.recreateAtlasGpu()
  ctx.noteAtlasRebuilt()

proc drawQuad*(
    ctx: VulkanContext,
    verts: array[4, Vec2],
    uvs: array[4, Vec2],
    colors: array[4, ColorRGBA],
) =
  ctx.checkBatch()
  let zero4 = vec4(0.0'f32)
  let offset = ctx.quadCount * 4
  ctx.positions.setVert2(offset + 0, verts[0])
  ctx.positions.setVert2(offset + 1, verts[1])
  ctx.positions.setVert2(offset + 2, verts[2])
  ctx.positions.setVert2(offset + 3, verts[3])

  ctx.uvs.setVert2(offset + 0, uvs[0])
  ctx.uvs.setVert2(offset + 1, uvs[1])
  ctx.uvs.setVert2(offset + 2, uvs[2])
  ctx.uvs.setVert2(offset + 3, uvs[3])

  ctx.colors.setVertColor(offset + 0, colors[0])
  ctx.colors.setVertColor(offset + 1, colors[1])
  ctx.colors.setVertColor(offset + 2, colors[2])
  ctx.colors.setVertColor(offset + 3, colors[3])
  ctx.setFillExtraColors(offset, rgba(0, 0, 0, 0), rgba(0, 0, 0, 0))

  ctx.sdfParams.setVert4(offset + 0, zero4)
  ctx.sdfParams.setVert4(offset + 1, zero4)
  ctx.sdfParams.setVert4(offset + 2, zero4)
  ctx.sdfParams.setVert4(offset + 3, zero4)

  ctx.sdfRadii.setVert4(offset + 0, zero4)
  ctx.sdfRadii.setVert4(offset + 1, zero4)
  ctx.sdfRadii.setVert4(offset + 2, zero4)
  ctx.sdfRadii.setVert4(offset + 3, zero4)

  let defaultFactors = vec2(0.0'f32, 0.0'f32)
  ctx.sdfFactors.setVert2(offset + 0, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 1, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 2, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 3, defaultFactors)

  when defined(emscripten):
    let modeVal = 0.0'f32
  else:
    let modeVal = 0'u16
  ctx.sdfModeAttr[offset + 0] = modeVal
  ctx.sdfModeAttr[offset + 1] = modeVal
  ctx.sdfModeAttr[offset + 2] = modeVal
  ctx.sdfModeAttr[offset + 3] = modeVal

  ctx.setRectMaskVert4IfNeeded(offset)
  inc ctx.quadCount

method drawFilledQuad*(
    ctx: VulkanContext, verts: array[4, Vec2], colors: array[4, ColorRGBA]
) =
  const imgKey = hash("rect")
  if imgKey notin ctx.entries:
    var image = newImage(4, 4)
    image.fill(rgba(255, 255, 255, 255))
    ctx.putImage(imgKey, image)

  let
    uv = ctx.entries[imgKey].xy + ctx.entries[imgKey].wh / 2.0'f32
    uvQuad = [uv, uv, uv, uv]

  let posQuad = [
    ceil(ctx.mat * verts[0]),
    ceil(ctx.mat * verts[1]),
    ceil(ctx.mat * verts[2]),
    ceil(ctx.mat * verts[3]),
  ]
  ctx.drawQuad(posQuad, uvQuad, colors)

proc drawUvRectAtlasSdf(
    ctx: VulkanContext,
    at, to: Vec2,
    uvAt, uvTo: Vec2,
    color: Color,
    mode: SdfMode,
    factors: Vec2,
    params: Vec4 = vec4(0.0'f32),
) =
  ctx.checkBatch()
  let
    posQuad = [
      ceil(ctx.mat * vec2(at.x, to.y)),
      ceil(ctx.mat * vec2(to.x, to.y)),
      ceil(ctx.mat * vec2(to.x, at.y)),
      ceil(ctx.mat * vec2(at.x, at.y)),
    ]
    uvQuad = [
      vec2(uvAt.x, uvTo.y),
      vec2(uvTo.x, uvTo.y),
      vec2(uvTo.x, uvAt.y),
      vec2(uvAt.x, uvAt.y),
    ]

  let offset = ctx.quadCount * 4
  ctx.positions.setVert2(offset + 0, posQuad[0])
  ctx.positions.setVert2(offset + 1, posQuad[1])
  ctx.positions.setVert2(offset + 2, posQuad[2])
  ctx.positions.setVert2(offset + 3, posQuad[3])

  ctx.uvs.setVert2(offset + 0, uvQuad[0])
  ctx.uvs.setVert2(offset + 1, uvQuad[1])
  ctx.uvs.setVert2(offset + 2, uvQuad[2])
  ctx.uvs.setVert2(offset + 3, uvQuad[3])

  let rgba = color.rgba()
  ctx.colors.setVertColor(offset + 0, rgba)
  ctx.colors.setVertColor(offset + 1, rgba)
  ctx.colors.setVertColor(offset + 2, rgba)
  ctx.colors.setVertColor(offset + 3, rgba)
  ctx.setFillExtraColors(offset, rgba(0, 0, 0, 0), rgba(0, 0, 0, 0))
  ctx.setFillExtraColors(offset, rgba(0, 0, 0, 0), rgba(0, 0, 0, 0))

  ctx.sdfParams.setVert4(offset + 0, params)
  ctx.sdfParams.setVert4(offset + 1, params)
  ctx.sdfParams.setVert4(offset + 2, params)
  ctx.sdfParams.setVert4(offset + 3, params)

  let zero4 = vec4(0.0'f32)
  ctx.sdfRadii.setVert4(offset + 0, zero4)
  ctx.sdfRadii.setVert4(offset + 1, zero4)
  ctx.sdfRadii.setVert4(offset + 2, zero4)
  ctx.sdfRadii.setVert4(offset + 3, zero4)

  ctx.sdfFactors.setVert2(offset + 0, factors)
  ctx.sdfFactors.setVert2(offset + 1, factors)
  ctx.sdfFactors.setVert2(offset + 2, factors)
  ctx.sdfFactors.setVert2(offset + 3, factors)

  when defined(emscripten):
    let modeVal = mode.int.float32
  else:
    let modeVal = mode.int.uint16
  ctx.sdfModeAttr[offset + 0] = modeVal
  ctx.sdfModeAttr[offset + 1] = modeVal
  ctx.sdfModeAttr[offset + 2] = modeVal
  ctx.sdfModeAttr[offset + 3] = modeVal

  ctx.setRectMaskVert4IfNeeded(offset)
  inc ctx.quadCount

proc imageUvBounds(rect: Rect, flipY: bool): tuple[uvAt: Vec2, uvTo: Vec2]

method drawMsdfImage*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    size: Vec2,
    pxRange: float32,
    sdThreshold: float32 = 0.5,
    strokeWeight: float32 = 0.0'f32,
    flipY: bool = false,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  let (uvAt, uvTo) = imageUvBounds(rect, flipY)
  let strokeW = max(0.0'f32, strokeWeight)
  let params = vec4(ctx.atlasSize.float32, strokeW, 0.0'f32, 0.0'f32)
  let modeSel: SdfMode =
    if strokeW > 0.0'f32: SdfMode.sdfModeMsdfAnnular else: SdfMode.sdfModeMsdf
  ctx.drawUvRectAtlasSdf(
    at = pos,
    to = pos + size,
    uvAt = uvAt,
    uvTo = uvTo,
    color = color,
    mode = modeSel,
    factors = vec2(pxRange, sdThreshold),
    params = params,
  )

method drawMtsdfImage*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    size: Vec2,
    pxRange: float32,
    sdThreshold: float32 = 0.5,
    strokeWeight: float32 = 0.0'f32,
    flipY: bool = false,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  let (uvAt, uvTo) = imageUvBounds(rect, flipY)
  let strokeW = max(0.0'f32, strokeWeight)
  let params = vec4(ctx.atlasSize.float32, strokeW, 0.0'f32, 0.0'f32)
  let modeSel: SdfMode =
    if strokeW > 0.0'f32: SdfMode.sdfModeMtsdfAnnular else: SdfMode.sdfModeMtsdf
  ctx.drawUvRectAtlasSdf(
    at = pos,
    to = pos + size,
    uvAt = uvAt,
    uvTo = uvTo,
    color = color,
    mode = modeSel,
    factors = vec2(pxRange, sdThreshold),
    params = params,
  )

method sdfAaFactor*(ctx: VulkanContext): float32 =
  ctx.aaFactor

method setSdfAaFactor*(ctx: VulkanContext, aaFactor: float32) =
  if ctx.aaFactor == aaFactor:
    return
  ctx.flush()
  ctx.aaFactor = aaFactor

proc setSdfGlobals*(ctx: VulkanContext, aaFactor: float32) =
  ctx.setSdfAaFactor(aaFactor)

proc drawUvRect(ctx: VulkanContext, at, to: Vec2, uvAt, uvTo: Vec2, color: Color) =
  ctx.checkBatch()
  let uvShift =
    if ctx.atlasSize > 0:
      ctx.activeTextSubpixelShift() / ctx.atlasSize.float32
    else:
      0.0'f32

  let
    posQuad = [
      ceil(ctx.mat * vec2(at.x, to.y)),
      ceil(ctx.mat * vec2(to.x, to.y)),
      ceil(ctx.mat * vec2(to.x, at.y)),
      ceil(ctx.mat * vec2(at.x, at.y)),
    ]
    uvQuad = [
      vec2(uvAt.x - uvShift, uvTo.y),
      vec2(uvTo.x - uvShift, uvTo.y),
      vec2(uvTo.x - uvShift, uvAt.y),
      vec2(uvAt.x - uvShift, uvAt.y),
    ]

  let offset = ctx.quadCount * 4
  ctx.positions.setVert2(offset + 0, posQuad[0])
  ctx.positions.setVert2(offset + 1, posQuad[1])
  ctx.positions.setVert2(offset + 2, posQuad[2])
  ctx.positions.setVert2(offset + 3, posQuad[3])

  ctx.uvs.setVert2(offset + 0, uvQuad[0])
  ctx.uvs.setVert2(offset + 1, uvQuad[1])
  ctx.uvs.setVert2(offset + 2, uvQuad[2])
  ctx.uvs.setVert2(offset + 3, uvQuad[3])

  let rgba = color.rgba()
  ctx.colors.setVertColor(offset + 0, rgba)
  ctx.colors.setVertColor(offset + 1, rgba)
  ctx.colors.setVertColor(offset + 2, rgba)
  ctx.colors.setVertColor(offset + 3, rgba)

  let zero4 = vec4(0.0'f32)
  ctx.sdfParams.setVert4(offset + 0, zero4)
  ctx.sdfParams.setVert4(offset + 1, zero4)
  ctx.sdfParams.setVert4(offset + 2, zero4)
  ctx.sdfParams.setVert4(offset + 3, zero4)

  ctx.sdfRadii.setVert4(offset + 0, zero4)
  ctx.sdfRadii.setVert4(offset + 1, zero4)
  ctx.sdfRadii.setVert4(offset + 2, zero4)
  ctx.sdfRadii.setVert4(offset + 3, zero4)

  let defaultFactors = vec2(0.0'f32, 0.0'f32)
  ctx.sdfFactors.setVert2(offset + 0, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 1, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 2, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 3, defaultFactors)

  when defined(emscripten):
    let modeVal = 0.0'f32
  else:
    let modeVal = 0'u16
  ctx.sdfModeAttr[offset + 0] = modeVal
  ctx.sdfModeAttr[offset + 1] = modeVal
  ctx.sdfModeAttr[offset + 2] = modeVal
  ctx.sdfModeAttr[offset + 3] = modeVal

  ctx.setRectMaskVert4IfNeeded(offset)
  inc ctx.quadCount

proc drawUvRect(
    ctx: VulkanContext, at, to: Vec2, uvAt, uvTo: Vec2, colors: array[4, ColorRGBA]
) =
  ctx.checkBatch()
  let uvShift =
    if ctx.atlasSize > 0:
      ctx.activeTextSubpixelShift() / ctx.atlasSize.float32
    else:
      0.0'f32

  let
    posQuad = [
      ceil(ctx.mat * vec2(at.x, to.y)),
      ceil(ctx.mat * vec2(to.x, to.y)),
      ceil(ctx.mat * vec2(to.x, at.y)),
      ceil(ctx.mat * vec2(at.x, at.y)),
    ]
    uvQuad = [
      vec2(uvAt.x - uvShift, uvTo.y),
      vec2(uvTo.x - uvShift, uvTo.y),
      vec2(uvTo.x - uvShift, uvAt.y),
      vec2(uvAt.x - uvShift, uvAt.y),
    ]

  let offset = ctx.quadCount * 4
  ctx.positions.setVert2(offset + 0, posQuad[0])
  ctx.positions.setVert2(offset + 1, posQuad[1])
  ctx.positions.setVert2(offset + 2, posQuad[2])
  ctx.positions.setVert2(offset + 3, posQuad[3])

  ctx.uvs.setVert2(offset + 0, uvQuad[0])
  ctx.uvs.setVert2(offset + 1, uvQuad[1])
  ctx.uvs.setVert2(offset + 2, uvQuad[2])
  ctx.uvs.setVert2(offset + 3, uvQuad[3])

  ctx.colors.setVertColor(offset + 0, colors[0])
  ctx.colors.setVertColor(offset + 1, colors[1])
  ctx.colors.setVertColor(offset + 2, colors[2])
  ctx.colors.setVertColor(offset + 3, colors[3])
  ctx.setFillExtraColors(offset, rgba(0, 0, 0, 0), rgba(0, 0, 0, 0))

  let zero4 = vec4(0.0'f32)
  ctx.sdfParams.setVert4(offset + 0, zero4)
  ctx.sdfParams.setVert4(offset + 1, zero4)
  ctx.sdfParams.setVert4(offset + 2, zero4)
  ctx.sdfParams.setVert4(offset + 3, zero4)

  ctx.sdfRadii.setVert4(offset + 0, zero4)
  ctx.sdfRadii.setVert4(offset + 1, zero4)
  ctx.sdfRadii.setVert4(offset + 2, zero4)
  ctx.sdfRadii.setVert4(offset + 3, zero4)

  let defaultFactors = vec2(0.0'f32, 0.0'f32)
  ctx.sdfFactors.setVert2(offset + 0, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 1, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 2, defaultFactors)
  ctx.sdfFactors.setVert2(offset + 3, defaultFactors)

  when defined(emscripten):
    let modeVal = 0.0'f32
  else:
    let modeVal = 0'u16
  ctx.sdfModeAttr[offset + 0] = modeVal
  ctx.sdfModeAttr[offset + 1] = modeVal
  ctx.sdfModeAttr[offset + 2] = modeVal
  ctx.sdfModeAttr[offset + 3] = modeVal

  ctx.setRectMaskVert4IfNeeded(offset)
  inc ctx.quadCount

proc drawUvRect(ctx: VulkanContext, rect, uvRect: Rect, color: Color) =
  ctx.drawUvRect(rect.xy, rect.xy + rect.wh, uvRect.xy, uvRect.xy + uvRect.wh, color)

proc drawUvRect(ctx: VulkanContext, rect, uvRect: Rect, colors: array[4, ColorRGBA]) =
  ctx.drawUvRect(rect.xy, rect.xy + rect.wh, uvRect.xy, uvRect.xy + uvRect.wh, colors)

proc tryGetImageRect(ctx: VulkanContext, imageId: Hash, rect: var Rect): bool =
  if imageId notin ctx.entries:
    return false
  rect = ctx.entries[imageId]
  true

proc imageUvBounds(rect: Rect, flipY: bool): tuple[uvAt: Vec2, uvTo: Vec2] =
  if flipY:
    return (vec2(rect.x, rect.y + rect.h), vec2(rect.x + rect.w, rect.y))
  (rect.xy, rect.xy + rect.wh)

proc drawImage*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    scale: float32,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  let wh = rect.wh * ctx.atlasSize.float32 * scale
  ctx.drawUvRect(pos, pos + wh, rect.xy, rect.xy + rect.wh, color)

proc drawImage*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    colors: array[4, ColorRGBA],
    scale: float32,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  let wh = rect.wh * ctx.atlasSize.float32 * scale
  ctx.drawUvRect(pos, pos + wh, rect.xy, rect.xy + rect.wh, colors)

method drawImage*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2,
    colors: array[4, ColorRGBA],
    size: Vec2,
    flipY: bool,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  let drawSize =
    if size.x > 0.0'f32 and size.y > 0.0'f32:
      size
    else:
      rect.wh * ctx.atlasSize.float32
  let (uvAt, uvTo) = imageUvBounds(rect, flipY)
  ctx.drawUvRect(pos, pos + drawSize, uvAt, uvTo, colors)

method drawImageAdj*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    size: Vec2,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  let adj = vec2(2 / ctx.atlasSize.float32)
  ctx.drawUvRect(pos, pos + size, rect.xy + adj, rect.xy + rect.wh - adj, color)

proc drawSprite*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    scale = 1.0,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  let wh = rect.wh * ctx.atlasSize.float32 * scale
  ctx.drawUvRect(pos - wh / 2, pos + wh / 2, rect.xy, rect.xy + rect.wh, color)

proc drawSprite*(
    ctx: VulkanContext,
    imageId: Hash,
    pos: Vec2 = vec2(0, 0),
    color = color(1, 1, 1, 1),
    size: Vec2,
) =
  var rect: Rect
  if not ctx.tryGetImageRect(imageId, rect):
    return
  ctx.drawUvRect(pos - size / 2, pos + size / 2, rect.xy, rect.xy + rect.wh, color)

method drawRect*(ctx: VulkanContext, rect: Rect, color: Color) =
  const imgKey = hash("rect")
  if imgKey notin ctx.entries:
    var image = newImage(4, 4)
    image.fill(rgba(255, 255, 255, 255))
    ctx.putImage(imgKey, image)

  let uvRect = ctx.entries[imgKey]
  ctx.drawUvRect(
    rect.xy,
    rect.xy + rect.wh,
    uvRect.xy + uvRect.wh / 2,
    uvRect.xy + uvRect.wh / 2,
    color,
  )

method drawRoundedRectSdf*(
    ctx: VulkanContext,
    rect: Rect,
    color: Color,
    radii: CornerRadii2D[float32],
    mode: SdfMode = sdfModeClipAA,
    factor: float32 = 4.0,
    spread: float32 = 0.0,
    shapeSize: Vec2 = vec2(0.0'f32, 0.0'f32),
) =
  let rgba = color.rgba()
  ctx.drawRoundedRectSdf(
    rect = rect,
    colors = [rgba, rgba, rgba, rgba],
    radii = radii,
    mode = mode,
    factor = factor,
    spread = spread,
    shapeSize = shapeSize,
  )

proc drawRoundedRectSdfVulkan(
    ctx: VulkanContext,
    rect: Rect,
    colors: array[4, ColorRGBA],
    radii: CornerRadii2D[float32],
    mode: SdfMode = sdfModeClipAA,
    factor: float32 = 4.0,
    spread: float32 = 0.0,
    shapeSize: Vec2 = vec2(0.0'f32, 0.0'f32),
    fillMode: int = SdfFillSolidOrVertex,
    fillMidColor: ColorRGBA = rgba(0, 0, 0, 0),
    fillStopColor: ColorRGBA = rgba(0, 0, 0, 0),
    fillMidPos: float32 = 0.5'f32,
) =
  if rect.w <= 0 or rect.h <= 0:
    return

  ctx.checkBatch()

  let
    quadHalfExtents = rect.wh * 0.5'f32
    insetMode = mode == sdfModeInsetShadow
    resolvedShapeSize =
      (if shapeSize.x > 0.0'f32 and shapeSize.y > 0.0'f32: shapeSize else: rect.wh)
    shapeHalfExtents =
      if insetMode:
        quadHalfExtents
      else:
        resolvedShapeSize * 0.5'f32
    params =
      if insetMode:
        vec4(quadHalfExtents.x, quadHalfExtents.y, shapeSize.x, shapeSize.y)
      else:
        vec4(
          quadHalfExtents.x, quadHalfExtents.y, shapeHalfExtents.x, shapeHalfExtents.y
        )
    encodedRadii = roundedRadiiVec(radii, shapeHalfExtents)
    r4 = encodedRadii.radii

  let
    at = rect.xy
    to = rect.xy + rect.wh
    uvAt = vec2(0.0'f32, 0.0'f32)
    uvTo = vec2(1.0'f32, 1.0'f32)

    posQuad = [
      ceil(ctx.mat * vec2(at.x, to.y)),
      ceil(ctx.mat * vec2(to.x, to.y)),
      ceil(ctx.mat * vec2(to.x, at.y)),
      ceil(ctx.mat * vec2(at.x, at.y)),
    ]
    uvQuad = [
      vec2(uvAt.x, uvTo.y),
      vec2(uvTo.x, uvTo.y),
      vec2(uvTo.x, uvAt.y),
      vec2(uvAt.x, uvAt.y),
    ]

  let offset = ctx.quadCount * 4
  ctx.positions.setVert2(offset + 0, posQuad[0])
  ctx.positions.setVert2(offset + 1, posQuad[1])
  ctx.positions.setVert2(offset + 2, posQuad[2])
  ctx.positions.setVert2(offset + 3, posQuad[3])

  ctx.uvs.setVert2(offset + 0, uvQuad[0])
  ctx.uvs.setVert2(offset + 1, uvQuad[1])
  ctx.uvs.setVert2(offset + 2, uvQuad[2])
  ctx.uvs.setVert2(offset + 3, uvQuad[3])

  ctx.colors.setVertColor(offset + 0, colors[0])
  ctx.colors.setVertColor(offset + 1, colors[1])
  ctx.colors.setVertColor(offset + 2, colors[2])
  ctx.colors.setVertColor(offset + 3, colors[3])
  ctx.setFillExtraColors(offset, fillMidColor, fillStopColor)

  ctx.sdfParams.setVert4(offset + 0, params)
  ctx.sdfParams.setVert4(offset + 1, params)
  ctx.sdfParams.setVert4(offset + 2, params)
  ctx.sdfParams.setVert4(offset + 3, params)

  ctx.sdfRadii.setVert4(offset + 0, r4)
  ctx.sdfRadii.setVert4(offset + 1, r4)
  ctx.sdfRadii.setVert4(offset + 2, r4)
  ctx.sdfRadii.setVert4(offset + 3, r4)

  let factors =
    if fillMode == SdfFillSolidOrVertex:
      vec2(factor, spread)
    else:
      vec2(factor, clamp(fillMidPos, 0.01'f32, 0.99'f32))
  ctx.sdfFactors.setVert2(offset + 0, factors)
  ctx.sdfFactors.setVert2(offset + 1, factors)
  ctx.sdfFactors.setVert2(offset + 2, factors)
  ctx.sdfFactors.setVert2(offset + 3, factors)

  let modeVal = encodeSdfMode(mode, fillMode, encodedRadii.elliptical)
  ctx.sdfModeAttr[offset + 0] = modeVal
  ctx.sdfModeAttr[offset + 1] = modeVal
  ctx.sdfModeAttr[offset + 2] = modeVal
  ctx.sdfModeAttr[offset + 3] = modeVal

  ctx.setRectMaskVert4IfNeeded(offset)
  inc ctx.quadCount

method drawRoundedRectSdf*(
    ctx: VulkanContext,
    rect: Rect,
    colors: array[4, ColorRGBA],
    radii: CornerRadii2D[float32],
    mode: SdfMode = sdfModeClipAA,
    factor: float32 = 4.0,
    spread: float32 = 0.0,
    shapeSize: Vec2 = vec2(0.0'f32, 0.0'f32),
) =
  ctx.drawRoundedRectSdfVulkan(
    rect = rect,
    colors = colors,
    radii = radii,
    mode = mode,
    factor = factor,
    spread = spread,
    shapeSize = shapeSize,
  )

method drawRoundedRectSdf*(
    ctx: VulkanContext,
    rect: Rect,
    fill: figbackend.BackendFill,
    radii: CornerRadii2D[float32],
    mode: SdfMode = sdfModeClipAA,
    factor: float32 = 4.0,
    spread: float32 = 0.0,
    shapeSize: Vec2 = vec2(0.0'f32, 0.0'f32),
) =
  if fill.kind == figbackend.bfLinear3 and
      mode in {sdfModeClipAA, sdfModeAnnular, sdfModeAnnularAA}:
    ctx.drawRoundedRectSdfVulkan(
      rect = rect,
      colors = [fill.lin3Start, fill.lin3Start, fill.lin3Start, fill.lin3Start],
      radii = radii,
      mode = mode,
      factor = factor,
      spread = spread,
      shapeSize = shapeSize,
      fillMode = linear3FillMode(fill.lin3Axis),
      fillMidColor = fill.lin3Mid,
      fillStopColor = fill.lin3Stop,
      fillMidPos = fill.lin3MidPos,
    )
  else:
    ctx.drawRoundedRectSdfVulkan(
      rect = rect,
      colors = figbackend.gradientColors(fill),
      radii = radii,
      mode = mode,
      factor = factor,
      spread = spread,
      shapeSize = shapeSize,
    )

proc drawQuadraticBezierSdfVulkan(
    ctx: VulkanContext,
    rect: Rect,
    colors: array[4, ColorRGBA],
    p0, p1, p2: Vec2,
    strokeWeight: float32,
    cap: StrokeCap,
    fillMode: int = SdfFillSolidOrVertex,
    fillMidColor: ColorRGBA = rgba(0, 0, 0, 0),
    fillStopColor: ColorRGBA = rgba(0, 0, 0, 0),
    fillMidPos: float32 = 0.5'f32,
) =
  if rect.w <= 0.0'f32 or rect.h <= 0.0'f32 or strokeWeight <= 0.0'f32:
    return

  ctx.checkBatch()

  let
    quadHalfExtents = rect.wh * 0.5'f32
    params = vec4(quadHalfExtents.x, quadHalfExtents.y, p0.x, p0.y)
    curve = vec4(p1.x, p1.y, p2.x, p2.y)

  let
    at = rect.xy
    to = rect.xy + rect.wh
    uvAt = vec2(0.0'f32, 0.0'f32)
    uvTo = vec2(1.0'f32, 1.0'f32)

    posQuad = [
      ceil(ctx.mat * vec2(at.x, to.y)),
      ceil(ctx.mat * vec2(to.x, to.y)),
      ceil(ctx.mat * vec2(to.x, at.y)),
      ceil(ctx.mat * vec2(at.x, at.y)),
    ]
    uvQuad = [
      vec2(uvAt.x, uvTo.y),
      vec2(uvTo.x, uvTo.y),
      vec2(uvTo.x, uvAt.y),
      vec2(uvAt.x, uvAt.y),
    ]

  let offset = ctx.quadCount * 4
  ctx.positions.setVert2(offset + 0, posQuad[0])
  ctx.positions.setVert2(offset + 1, posQuad[1])
  ctx.positions.setVert2(offset + 2, posQuad[2])
  ctx.positions.setVert2(offset + 3, posQuad[3])

  ctx.uvs.setVert2(offset + 0, uvQuad[0])
  ctx.uvs.setVert2(offset + 1, uvQuad[1])
  ctx.uvs.setVert2(offset + 2, uvQuad[2])
  ctx.uvs.setVert2(offset + 3, uvQuad[3])

  ctx.colors.setVertColor(offset + 0, colors[0])
  ctx.colors.setVertColor(offset + 1, colors[1])
  ctx.colors.setVertColor(offset + 2, colors[2])
  ctx.colors.setVertColor(offset + 3, colors[3])
  ctx.setFillExtraColors(offset, fillMidColor, fillStopColor)

  ctx.sdfParams.setVert4(offset + 0, params)
  ctx.sdfParams.setVert4(offset + 1, params)
  ctx.sdfParams.setVert4(offset + 2, params)
  ctx.sdfParams.setVert4(offset + 3, params)

  ctx.sdfRadii.setVert4(offset + 0, curve)
  ctx.sdfRadii.setVert4(offset + 1, curve)
  ctx.sdfRadii.setVert4(offset + 2, curve)
  ctx.sdfRadii.setVert4(offset + 3, curve)

  let factors =
    if fillMode == SdfFillSolidOrVertex:
      vec2(strokeWeight, 0.0'f32)
    else:
      vec2(strokeWeight, clamp(fillMidPos, 0.01'f32, 0.99'f32))
  ctx.sdfFactors.setVert2(offset + 0, factors)
  ctx.sdfFactors.setVert2(offset + 1, factors)
  ctx.sdfFactors.setVert2(offset + 2, factors)
  ctx.sdfFactors.setVert2(offset + 3, factors)

  let modeVal = encodeSdfMode(figbackend.bezierStrokeSdfMode(cap), fillMode)
  ctx.sdfModeAttr[offset + 0] = modeVal
  ctx.sdfModeAttr[offset + 1] = modeVal
  ctx.sdfModeAttr[offset + 2] = modeVal
  ctx.sdfModeAttr[offset + 3] = modeVal

  ctx.setRectMaskVert4IfNeeded(offset)
  inc ctx.quadCount

method drawQuadraticBezierSdf*(
    ctx: VulkanContext,
    rect: Rect,
    fill: figbackend.BackendFill,
    p0, p1, p2: Vec2,
    strokeWeight: float32,
    cap: StrokeCap,
) =
  if fill.kind == figbackend.bfLinear3:
    ctx.drawQuadraticBezierSdfVulkan(
      rect = rect,
      colors = [fill.lin3Start, fill.lin3Start, fill.lin3Start, fill.lin3Start],
      p0 = p0,
      p1 = p1,
      p2 = p2,
      strokeWeight = strokeWeight,
      cap = cap,
      fillMode = linear3FillMode(fill.lin3Axis),
      fillMidColor = fill.lin3Mid,
      fillStopColor = fill.lin3Stop,
      fillMidPos = fill.lin3MidPos,
    )
  else:
    ctx.drawQuadraticBezierSdfVulkan(
      rect = rect,
      colors = figbackend.gradientColors(fill),
      p0 = p0,
      p1 = p1,
      p2 = p2,
      strokeWeight = strokeWeight,
      cap = cap,
    )

proc runBackdropSeparableBlur(
    ctx: VulkanContext, blurRadius: float32, blurRect: VkRect2D
) =
  vulkanBlurRunSeparable(ctx, blurRadius, blurRect)

method drawBackdropBlur*(
    ctx: VulkanContext, rect: Rect, radii: CornerRadii2D[float32], blurRadius: float32
) =
  if blurRadius <= 0.0'f32 or rect.w <= 0.0'f32 or rect.h <= 0.0'f32:
    return
  if not ctx.commandRecording or ctx.targetImage == vkNullImage:
    return

  ctx.flush()
  ctx.beginRenderPassIfNeeded()
  if ctx.renderPassBegun:
    vkCmdEndRenderPass(ctx.commandBuffer)
    ctx.renderPassBegun = false

  let width = max(1'i32, ctx.targetExtent.width.int32)
  let height = max(1'i32, ctx.targetExtent.height.int32)
  if width <= 0 or height <= 0:
    return

  let blurKernelReach = max(blurRadius, 8.0'f32)
  let blurPad = max(1'i32, int32(ceil(blurKernelReach + 2.0'f32)))
  let x0 = max(0'i32, int32(floor(rect.x - blurPad.float32)))
  let y0 = max(0'i32, int32(floor(rect.y - blurPad.float32)))
  let x1 = min(width, int32(ceil(rect.x + rect.w + blurPad.float32)))
  let y1 = min(height, int32(ceil(rect.y + rect.h + blurPad.float32)))
  if x1 <= x0 or y1 <= y0:
    return
  let blurRect = newVkRect2D(
    offset = newVkOffset2D(x = x0, y = y0),
    extent = newVkExtent2D(width = (x1 - x0).uint32, height = (y1 - y0).uint32),
  )

  ctx.ensureBackdropImage(width, height)
  if ctx.backdropImage.isNilOrEmpty or ctx.backdropImage.view == vkNullImageView:
    return

  let backdropOldLayout =
    if ctx.backdropLayoutReady:
      VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
    else:
      VK_IMAGE_LAYOUT_UNDEFINED
  let backdropSrcAccess =
    if ctx.backdropLayoutReady:
      VkAccessFlags{ShaderReadBit}
    else:
      0.VkAccessFlags
  let backdropSrcStage =
    if ctx.backdropLayoutReady:
      VkPipelineStageFlags{FragmentShaderBit}
    else:
      VkPipelineStageFlags{TopOfPipeBit}

  var backdropToTransfer = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: backdropSrcAccess,
    dstAccessMask: VkAccessFlags{TransferWriteBit},
    oldLayout: backdropOldLayout,
    newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.backdropImage.handle,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    ctx.commandBuffer,
    backdropSrcStage,
    VkPipelineStageFlags{TransferBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    backdropToTransfer.addr,
  )

  var swapchainToTransfer = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: 0.VkAccessFlags,
    dstAccessMask: VkAccessFlags{TransferReadBit},
    oldLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    newLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.targetImage,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    ctx.commandBuffer,
    VkPipelineStageFlags{BottomOfPipeBit},
    VkPipelineStageFlags{TransferBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    swapchainToTransfer.addr,
  )

  var copyRegion = VkImageCopy(
    srcSubresource: newVkImageSubresourceLayers(
      aspectMask = VkImageAspectFlags{ColorBit},
      mipLevel = 0,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
    srcOffset: newVkOffset3D(x = blurRect.offset.x, y = blurRect.offset.y, z = 0),
    dstSubresource: newVkImageSubresourceLayers(
      aspectMask = VkImageAspectFlags{ColorBit},
      mipLevel = 0,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
    dstOffset: newVkOffset3D(x = blurRect.offset.x, y = blurRect.offset.y, z = 0),
    extent: newVkExtent3D(
      width = blurRect.extent.width, height = blurRect.extent.height, depth = 1
    ),
  )
  vkCmdCopyImage(
    ctx.commandBuffer, ctx.targetImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    ctx.backdropImage.handle, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, copyRegion.addr,
  )

  var backdropToRead = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: VkAccessFlags{TransferWriteBit},
    dstAccessMask: VkAccessFlags{ShaderReadBit},
    oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
    newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.backdropImage.handle,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    ctx.commandBuffer,
    VkPipelineStageFlags{TransferBit},
    VkPipelineStageFlags{FragmentShaderBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    backdropToRead.addr,
  )

  var swapchainToPresent = VkImageMemoryBarrier(
    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    pNext: nil,
    srcAccessMask: VkAccessFlags{TransferReadBit},
    dstAccessMask: 0.VkAccessFlags,
    oldLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
    newLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
    image: ctx.targetImage,
    subresourceRange: newVkImageSubresourceRange(
      aspectMask = VkImageAspectFlags{ColorBit},
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    ),
  )
  vkCmdPipelineBarrier(
    ctx.commandBuffer,
    VkPipelineStageFlags{TransferBit},
    VkPipelineStageFlags{BottomOfPipeBit},
    0.VkDependencyFlags,
    0,
    nil,
    0,
    nil,
    1,
    swapchainToPresent.addr,
  )
  ctx.backdropLayoutReady = true
  ctx.runBackdropSeparableBlur(blurRadius, blurRect)

  ctx.drawRoundedRectSdf(
    rect = rect,
    color = whiteColor,
    radii = radii,
    mode = figbackend.SdfMode.sdfModeBackdropBlur,
    factor = blurRadius,
    spread = 0.0'f32,
    shapeSize = vec2(0.0'f32, 0.0'f32),
  )

proc line*(ctx: VulkanContext, a: Vec2, b: Vec2, weight: float32, color: Color) =
  let hash = hash((2345, a, b, (weight * 100).int, hash(color)))

  let
    w = ceil(abs(b.x - a.x)).int
    h = ceil(abs(a.y - b.y)).int
    pos = vec2(min(a.x, b.x), min(a.y, b.y))

  if w == 0 or h == 0:
    return

  if hash notin ctx.entries:
    let
      image = newImage(w, h)
      c = newContext(image)
    c.fillStyle = rgba(255, 255, 255, 255)
    c.lineWidth = weight
    c.strokeSegment(segment(a - pos, b - pos))
    ctx.putImage(hash, image)
  let uvRect = ctx.entries[hash]
  ctx.drawUvRect(
    pos, pos + vec2(w.float32, h.float32), uvRect.xy, uvRect.xy + uvRect.wh, color
  )

proc linePolygon*(ctx: VulkanContext, poly: seq[Vec2], weight: float32, color: Color) =
  for i in 0 ..< poly.len:
    ctx.line(poly[i], poly[(i + 1) mod poly.len], weight, color)

proc intersectRects(a, b: Rect): Rect =
  let
    x0 = max(a.x, b.x)
    y0 = max(a.y, b.y)
    x1 = min(a.x + a.w, b.x + b.w)
    y1 = min(a.y + a.h, b.y + b.h)
  if x1 <= x0 or y1 <= y0:
    return rect(0, 0, 0, 0)
  rect(x0, y0, x1 - x0, y1 - y0)

proc clearMask*(ctx: VulkanContext) =
  ctx.flush()

method beginMask*(ctx: VulkanContext, clipRect: Rect, radii: CornerRadii2D[float32]) =
  ctx.flush()
  ctx.pendingMaskValid = false
  ctx.maskBegun = true
  inc ctx.maskDepth

  ctx.pendingMaskRect = clipRect
  ctx.pendingMaskValid = true

method endMask*(ctx: VulkanContext) =
  ctx.flush()
  ctx.maskBegun = false

  let maskRect =
    if ctx.pendingMaskValid:
      ctx.pendingMaskRect
    else:
      ctx.fullFrameRect()
  let effective =
    if ctx.clipRects.len > 0:
      intersectRects(ctx.clipRects[^1], maskRect)
    else:
      maskRect
  ctx.clipRects.add(effective)
  ctx.applyClipScissor()
  ctx.pendingMaskValid = false

method popMask*(ctx: VulkanContext) =
  ctx.flush()
  if ctx.maskDepth > 0:
    dec ctx.maskDepth
  if ctx.clipRects.len > 0:
    discard ctx.clipRects.pop()
  ctx.applyClipScissor()

method beginRectMask*(
    ctx: VulkanContext, maskRect: Rect, radii: CornerRadii2D[float32]
) =
  if ctx.rectMaskStack.len == 0 and maskRect.w > 0.0'f32 and maskRect.h > 0.0'f32:
    ctx.rectMaskStack.add(ctx.makeRectMask(maskRect, radii))
  else:
    ctx.beginMask(maskRect, radii)
    ctx.endMask()
    ctx.rectMaskStack.add(RectMask(kind: rmkMask))

method popRectMask*(ctx: VulkanContext) =
  let rectMask = ctx.rectMaskStack.pop()
  if rectMask.kind == rmkMask:
    ctx.popMask()

proc beginFrame*(
    ctx: VulkanContext,
    frameSize: Vec2,
    proj: Mat4,
    clearMain = false,
    clearMainColor: Color = whiteColor,
) =
  ctx.frameBegun = true
  ctx.commandRecording = false
  ctx.renderPassBegun = false
  ctx.maskBegun = false
  ctx.maskDepth = 0
  ctx.pendingMaskValid = false
  ctx.clipRects.setLen(0)
  ctx.rectMaskStack.setLen(0)
  ctx.batchHasRectMask = false
  ctx.frameSize = frameSize
  ctx.proj = proj
  ctx.frameNeedsClear = true
  ctx.frameClearColor =
    if clearMain:
      clearMainColor
    else:
      rgba(0, 0, 0, 255).color

  ctx.ensureGpuRuntime()

  let width = max(1, frameSize.x.int32)
  let height = max(1, frameSize.y.int32)
  ctx.ensureOffscreenTarget(width, height)

  ctx.frameIndex = (ctx.frameIndex + 1) mod 2
  ctx.targetImage = ctx.swapImages[ctx.frameIndex]
  ctx.targetMemory = ctx.swapMemories[ctx.frameIndex]
  ctx.targetView = ctx.swapViews[ctx.frameIndex]
  ctx.targetFramebuffer = ctx.swapFramebuffers[ctx.frameIndex]
  ctx.targetFd = ctx.swapFds[ctx.frameIndex]
  ctx.commandBuffer = ctx.swapCommandBuffers[ctx.frameIndex]
  ctx.renderFinishedSemaphore = ctx.swapSemaphores[ctx.frameIndex]
  ctx.inFlightFence = ctx.swapFences[ctx.frameIndex]

  if ctx.targetImage == vkNullImage:
    return
  ctx.ensureBackdropImage(width, height)

  # HACK: This blocks.
  discard vkWaitForFences(
    ctx.device, 1, ctx.inFlightFence.addr, VkBool32(VkTrue), uint64(16000000)
  )
  ctx.clearFrameVertexUploads()

  checkVkResult vkResetFences(ctx.device, 1, ctx.inFlightFence.addr)
  checkVkResult vkResetCommandBuffer(ctx.commandBuffer, 0.VkCommandBufferResetFlags)

  let beginInfo = newVkCommandBufferBeginInfo(pInheritanceInfo = nil)
  checkVkResult vkBeginCommandBuffer(ctx.commandBuffer, beginInfo.addr)
  ctx.commandRecording = true

  if ctx.atlasDirty:
    ctx.recordAtlasUpload(ctx.commandBuffer)

method beginFrame*(
    ctx: VulkanContext,
    frameSize: Vec2,
    clearMain = false,
    clearMainColor: Color = whiteColor,
) =
  beginFrame(
    ctx,
    frameSize,
    ortho[float32](0.0, frameSize.x, frameSize.y, 0, -1000.0, 1000.0),
    clearMain = clearMain,
    clearMainColor = clearMainColor,
  )

method endFrame*(ctx: VulkanContext) =
  ctx.frameBegun = false

  if ctx.targetImage == vkNullImage or not ctx.commandRecording:
    return

  ctx.flush()
  ctx.beginRenderPassIfNeeded()
  if ctx.renderPassBegun:
    vkCmdEndRenderPass(ctx.commandBuffer)
    ctx.renderPassBegun = false
  when UseVulkanReadback:
    ctx.readbackReady = false
    ctx.recordSwapchainReadback()
  else:
    ctx.readbackReady = false
  checkVkResult vkEndCommandBuffer(ctx.commandBuffer)

  let waitStages = [VkPipelineStageFlags{ColorAttachmentOutputBit, TransferBit}]
  let submitInfo = newVkSubmitInfo(
    waitSemaphores = [],
    waitDstStageMask = waitStages,
    commandBuffers = [ctx.commandBuffer],
    signalSemaphores = [ctx.renderFinishedSemaphore],
  )
  checkVkResult vkQueueSubmit(ctx.queue, 1, submitInfo.addr, ctx.inFlightFence)

  ctx.commandRecording = false

proc destroyGpu(ctx: VulkanContext) =
  if ctx.isNil:
    return

  if ctx.device != vkNullDevice:
    discard vkDeviceWaitIdle(ctx.device)

  for i in 0 ..< 2:
    if ctx.swapSemaphores[i] != vkNullSemaphore:
      vkDestroySemaphore(ctx.device, ctx.swapSemaphores[i], nil)
      ctx.swapSemaphores[i] = vkNullSemaphore
    if ctx.swapFences[i] != vkNullFence:
      vkDestroyFence(ctx.device, ctx.swapFences[i], nil)
      ctx.swapFences[i] = vkNullFence

  if ctx.commandPool != vkNullCommandPool:
    vkDestroyCommandPool(ctx.device, ctx.commandPool, nil)
    ctx.commandPool = vkNullCommandPool

  ctx.commandBuffer = vkNullCommandBuffer
  ctx.renderFinishedSemaphore = vkNullSemaphore
  ctx.inFlightFence = vkNullFence

  ctx.destroyOffscreenTarget()
  ctx.destroyPipelineObjects()

  if ctx.vertShader != vkNullShaderModule:
    destroyShaderModule(ctx.device, ctx.vertShader)
    ctx.vertShader = vkNullShaderModule
  if ctx.fragShader != vkNullShaderModule:
    destroyShaderModule(ctx.device, ctx.fragShader)
    ctx.fragShader = vkNullShaderModule
  if ctx.blurVertShader != vkNullShaderModule:
    destroyShaderModule(ctx.device, ctx.blurVertShader)
    ctx.blurVertShader = vkNullShaderModule
  if ctx.blurFragShader != vkNullShaderModule:
    destroyShaderModule(ctx.device, ctx.blurFragShader)
    ctx.blurFragShader = vkNullShaderModule

  if ctx.descriptorPool != vkNullDescriptorPool:
    destroyDescriptorPool(ctx.device, ctx.descriptorPool)
    ctx.descriptorPool = vkNullDescriptorPool
  if ctx.descriptorSetLayout != vkNullDescriptorSetLayout:
    destroyDescriptorSetLayout(ctx.device, ctx.descriptorSetLayout)
    ctx.descriptorSetLayout = vkNullDescriptorSetLayout
  if ctx.blurDescriptorPool != vkNullDescriptorPool:
    destroyDescriptorPool(ctx.device, ctx.blurDescriptorPool)
    ctx.blurDescriptorPool = vkNullDescriptorPool
  if ctx.blurDescriptorSetLayout != vkNullDescriptorSetLayout:
    destroyDescriptorSetLayout(ctx.device, ctx.blurDescriptorSetLayout)
    ctx.blurDescriptorSetLayout = vkNullDescriptorSetLayout

  if ctx.atlasSampler != vkNullSampler:
    vkDestroySampler(ctx.device, ctx.atlasSampler, nil)
    ctx.atlasSampler = vkNullSampler
  ctx.atlasImage = nil
  ctx.backdropImage = nil
  ctx.backdropBlurTempImage = nil
  ctx.atlasUploadBuffer = nil
  ctx.vertexBuffer = nil
  ctx.indexBuffer = nil
  ctx.vsUniformBuffer = nil
  ctx.fsUniformBuffer = nil
  for i in 0 ..< ctx.blurUniformBuffers.len:
    ctx.blurUniformBuffers[i] = nil
  ctx.readbackBuffer = nil
  ctx.clearFrameVertexUploads()

  if ctx.device != vkNullDevice:
    destroyDevice(ctx.device)
    ctx.device = vkNullDevice

  if ctx.instance != vkNullInstance:
    destroyInstance(ctx.instance)
    ctx.instance = vkNullInstance

  ctx.gpuReady = false
  ctx.commandRecording = false
  ctx.renderPassBegun = false
  ctx.frameNeedsClear = false
  ctx.targetRequestedWidth = 0
  ctx.targetRequestedHeight = 0
  ctx.atlasLayoutReady = false
  ctx.backdropLayoutReady = false
  ctx.backdropBlurTempLayoutReady = false
  ctx.backdropWidth = 0
  ctx.backdropHeight = 0
  ctx.backdropFormat = VK_FORMAT_UNDEFINED
  ctx.readbackReady = false

proc newContext*(
    atlasSize = 1024,
    atlasMargin = 4,
    maxQuads = quadLimit,
    pixelate = false,
    pixelScale = 1.0,
): VulkanContext =
  result = VulkanContext()
  result.atlasSize = atlasSize
  result.initialAtlasSize = atlasSize
  result.atlasMargin = atlasMargin
  result.maxQuads = maxQuads
  result.mat = mat4()
  result.mats = @[]
  result.entries = initTable[Hash, Rect]()
  result.atlasEntryMeta = initTable[Hash, AtlasEntryMeta]()
  result.heights = newSeq[uint16](atlasSize)
  result.pixelate = pixelate
  result.pixelScale = pixelScale
  result.aaFactor = figbackend.DefaultSdfAaFactor
  result.textLcdFilteringEnabled = false
  result.textSubpixelPositioningEnabled = false
  result.textSubpixelGlyphVariantsEnabled = false
  result.textSubpixelShift = 0.0'f32
  result.atlasPixels = newImage(atlasSize, atlasSize)
  result.atlasPixels.fill(rgba(0, 0, 0, 0))
  result.atlasDirty = true
  result.atlasLayoutReady = false
  result.ensureImageMessageSubscription()
  result.noteAtlasCreated()

  result.positions = newSeq[float32](2 * maxQuads * 4)
  result.colors = newSeq[uint8](4 * maxQuads * 4)
  result.fillMidColors = newSeq[uint8](4 * maxQuads * 4)
  result.fillStopColors = newSeq[uint8](4 * maxQuads * 4)
  result.uvs = newSeq[float32](2 * maxQuads * 4)
  result.sdfParams = newSeq[float32](4 * maxQuads * 4)
  result.sdfRadii = newSeq[float32](4 * maxQuads * 4)
  result.sdfModeAttr = newSeq[SdfModeData](maxQuads * 4)
  result.sdfFactors = newSeq[float32](2 * maxQuads * 4)
  result.rectMaskParams = newSeq[float32](4 * maxQuads * 4)
  result.rectMaskRadii = newSeq[float32](4 * maxQuads * 4)
  result.rectMaskMatX = newSeq[float32](4 * maxQuads * 4)
  result.rectMaskMatY = newSeq[float32](4 * maxQuads * 4)
  result.vertexScratch = newSeq[Vertex](maxQuads * 4)

  result.indices = newSeq[uint16](maxQuads * 6)
  for i in 0 ..< maxQuads:
    let offset = i * 4
    let base = i * 6
    result.indices[base + 0] = (offset + 3).uint16
    result.indices[base + 1] = (offset + 0).uint16
    result.indices[base + 2] = (offset + 1).uint16
    result.indices[base + 3] = (offset + 2).uint16
    result.indices[base + 4] = (offset + 3).uint16
    result.indices[base + 5] = (offset + 1).uint16

  result.instance = vkNullInstance
  result.physicalDevice = vkNullPhysicalDevice
  result.device = vkNullDevice
  result.queue = vkNullQueue
  result.queueFamily = 0

  result.targetImage = vkNullImage
  result.targetMemory = vkNullMemory
  result.targetView = vkNullImageView
  result.targetFramebuffer = vkNullFramebuffer
  result.targetFormat = VK_FORMAT_UNDEFINED
  result.targetExtent = VkExtent2D(width: 0, height: 0)
  result.targetRequestedWidth = 0
  result.targetRequestedHeight = 0
  result.targetFd = -1

  result.readbackBuffer = nil
  result.readbackBytes = 0.VkDeviceSize
  result.readbackWidth = 0
  result.readbackHeight = 0
  result.readbackReady = false
  result.atlasImage = nil
  result.backdropImage = nil
  result.backdropBlurTempImage = nil
  result.backdropLayoutReady = false
  result.backdropBlurTempLayoutReady = false
  result.backdropWidth = 0
  result.backdropHeight = 0
  result.backdropFormat = VK_FORMAT_UNDEFINED
  result.backdropBlurFramebuffer = vkNullFramebuffer
  result.backdropBlurTempFramebuffer = vkNullFramebuffer
  result.blurRenderPass = vkNullRenderPass
  result.blurDescriptorSetLayout = vkNullDescriptorSetLayout
  result.blurDescriptorPool = vkNullDescriptorPool
  result.blurDescriptorSets = [vkNullDescriptorSet, vkNullDescriptorSet]
  result.blurPipelineLayout = vkNullPipelineLayout
  result.blurPipeline = vkNullPipeline
  result.blurVertShader = vkNullShaderModule
  result.blurFragShader = vkNullShaderModule
  result.blurUniformBuffers = [VulkanBuffer(nil), VulkanBuffer(nil)]
  result.atlasSampler = vkNullSampler
  result.atlasUploadBuffer = nil
  result.atlasUploadBytes = 0.VkDeviceSize
  result.vertexBuffer = nil
  result.vertexBufferBytes = 0.VkDeviceSize
  result.indexBuffer = nil
  result.indexBufferBytes = 0.VkDeviceSize
  result.vsUniformBuffer = nil
  result.fsUniformBuffer = nil
  result.commandPool = vkNullCommandPool
  result.commandBuffer = vkNullCommandBuffer
  result.renderFinishedSemaphore = vkNullSemaphore
  result.inFlightFence = vkNullFence
  result.descriptorSetLayout = vkNullDescriptorSetLayout
  result.descriptorPool = vkNullDescriptorPool
  result.descriptorSet = vkNullDescriptorSet
  result.pipelineLayout = vkNullPipelineLayout
  result.pipeline = vkNullPipeline
  result.renderPass = vkNullRenderPass
  result.vertShader = vkNullShaderModule
  result.fragShader = vkNullShaderModule
  result.frameSize = vec2(1.0'f32, 1.0'f32)
  result.proj = mat4()
  result.pendingMaskRect = rect(0.0'f32, 0.0'f32, 0.0'f32, 0.0'f32)
  result.pendingMaskValid = false
  result.clipRects = @[]
  result.renderPassBegun = false
  result.frameNeedsClear = false
  result.frameClearColor = rgba(0, 0, 0, 255).color
  result.frameVertexBuffers = @[]

method translate*(ctx: VulkanContext, v: Vec2) =
  ctx.mat = ctx.mat * translate(vec3(v))

method rotate*(ctx: VulkanContext, angle: float32) =
  ctx.mat = ctx.mat * rotateZ(angle)

method scale*(ctx: VulkanContext, s: float32) =
  ctx.mat = ctx.mat * scale(vec3(s))

method scale*(ctx: VulkanContext, s: Vec2) =
  ctx.mat = ctx.mat * scale(vec3(s.x, s.y, 1))

method applyTransform*(ctx: VulkanContext, m: Mat4) =
  ctx.mat = ctx.mat * m

method saveTransform*(ctx: VulkanContext) =
  ctx.mats.add ctx.mat

method restoreTransform*(ctx: VulkanContext) =
  if ctx.mats.len > 0:
    ctx.mat = ctx.mats.pop()

method transformMirrorsY*(ctx: VulkanContext): bool =
  let origin = (ctx.mat * vec3(0.0'f32, 0.0'f32, 1.0'f32)).xy
  let xAxis = (ctx.mat * vec3(1.0'f32, 0.0'f32, 1.0'f32)).xy - origin
  let yAxis = (ctx.mat * vec3(0.0'f32, 1.0'f32, 1.0'f32)).xy - origin
  let determinant = xAxis.x * yAxis.y - xAxis.y * yAxis.x
  determinant < 0.0'f32

proc clearTransform*(ctx: VulkanContext) =
  ctx.mat = mat4()
  ctx.mats.setLen(0)

proc fromScreen*(ctx: VulkanContext, windowFrame: Vec2, v: Vec2): Vec2 =
  (ctx.mat.inverse() * vec3(v.x, windowFrame.y - v.y, 0)).xy

proc toScreen*(ctx: VulkanContext, windowFrame: Vec2, v: Vec2): Vec2 =
  result = (ctx.mat * vec3(v.x, v.y, 1)).xy
  result.y = -result.y + windowFrame.y

proc releaseBackendResources*(ctx: VulkanContext) =
  ctx.destroyGpu()

proc vulkanDriverInfo*(ctx: VulkanContext): VulkanDriverInfo =
  ctx.driverInfo

proc ensureInstance*(ctx: VulkanContext) =
  if ctx.instance != vkNullInstance:
    return
  vkPreload()
  ctx.instance = ctx.createInstanceWithFallback()
  vkInit(ctx.instance, load1_2 = false, load1_3 = false)

proc instanceHandle*(ctx: VulkanContext): pointer =
  cast[pointer](ctx.instance)

method readPixels*(
    ctx: VulkanContext, frame: Rect = rect(0, 0, 0, 0), readFront = true
): Image =
  when not UseVulkanReadback:
    discard readFront
    raise newException(
      ValueError,
      "Vulkan readPixels is disabled; build with -d:figdraw.vulkanReadback=on",
    )
  else:
    discard readFront
    if not ctx.gpuReady:
      raise newException(ValueError, "Vulkan context is not initialized")
    if ctx.readbackBuffer.isNilOrEmpty or not ctx.readbackReady:
      raise newException(ValueError, "No Vulkan frame has been rendered yet")
    if ctx.readbackWidth <= 0 or ctx.readbackHeight <= 0:
      raise newException(ValueError, "Vulkan readback dimensions are invalid")

    checkVkResult vkWaitForFences(
      ctx.device, 1, ctx.inFlightFence.addr, VkBool32(VkTrue), high(uint64)
    )

    let texW = ctx.readbackWidth.int
    let texH = ctx.readbackHeight.int

    var x = frame.x.int
    var y = frame.y.int
    var w = frame.w.int
    var h = frame.h.int
    if w <= 0 or h <= 0:
      x = 0
      y = 0
      w = texW
      h = texH

    x = clamp(x, 0, texW)
    y = clamp(y, 0, texH)
    w = clamp(w, 0, texW - x)
    h = clamp(h, 0, texH - y)

    if w <= 0 or h <= 0:
      result = newImage(1, 1)
      return

    let mapped = cast[ptr UncheckedArray[uint8]](mapMemory(
      ctx.device, ctx.readbackBuffer.allocation, 0.VkDeviceSize, ctx.readbackBytes,
      0.VkMemoryMapFlags,
    ))
    if mapped.isNil:
      raise newException(ValueError, "Failed to map Vulkan readback memory")
    defer:
      unmapMemory(ctx.device, ctx.readbackBuffer.allocation)

    result = newImage(w, h)
    let stride = texW * 4
    let bgrFormat =
      case ctx.targetFormat
      of VK_FORMAT_R8G8B8A8_UNORM, VK_FORMAT_B8G8R8A8_SRGB: true
      else: false

    for row in 0 ..< h:
      let srcRow = y + row
      var src = srcRow * stride + x * 4
      for col in 0 ..< w:
        let dst = row * w + col
        let b = mapped[src + 0]
        let g = mapped[src + 1]
        let r = mapped[src + 2]
        let a = mapped[src + 3]
        if bgrFormat:
          result.data[dst] = rgbx(r, g, b, a)
        else:
          result.data[dst] = rgbx(b, g, r, a)
        src += 4

method kind*(ctx: VulkanContext): figbackend.RendererBackendKind =
  figbackend.RendererBackendKind.rbVulkan

method entriesPtr*(ctx: VulkanContext): ptr Table[Hash, Rect] =
  ctx.entries.addr

method atlasEntryMetaPtr*(ctx: VulkanContext): var Table[Hash, AtlasEntryMeta] =
  result = ctx.atlasEntryMeta

method atlasSize*(ctx: VulkanContext): int =
  ctx.atlasSize

method atlasPackedArea*(ctx: VulkanContext): int =
  for height in ctx.heights:
    result += int(height)

method pixelScale*(ctx: VulkanContext): float32 =
  ctx.pixelScale

method textLcdFilteringEnabled*(ctx: VulkanContext): bool =
  ctx.textLcdFilteringEnabled

method setTextLcdFilteringEnabled*(ctx: VulkanContext, enabled: bool) =
  ctx.textLcdFilteringEnabled = enabled

method textSubpixelPositioningEnabled*(ctx: VulkanContext): bool =
  ctx.textSubpixelPositioningEnabled

method setTextSubpixelPositioningEnabled*(ctx: VulkanContext, enabled: bool) =
  ctx.textSubpixelPositioningEnabled = enabled

method textSubpixelGlyphVariantsEnabled*(ctx: VulkanContext): bool =
  ctx.textSubpixelGlyphVariantsEnabled

method setTextSubpixelGlyphVariantsEnabled*(ctx: VulkanContext, enabled: bool) =
  ctx.textSubpixelGlyphVariantsEnabled = enabled

method setTextSubpixelShift*(ctx: VulkanContext, shift: float32) =
  ctx.textSubpixelShift = shift
