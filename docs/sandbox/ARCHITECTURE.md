# Sirius and Sandboxing
**Author**: Trayambak Rai (`xtrayambak@disroot.org`)
Sirius aims to become a multiprocessing, sandboxed web engine.

I learnt a lot along the way while building Ferus' IPC and multiprocessing systems, and I aim to address many of the pitfalls that were present there.

From hereon out, the "master" process refers to the `sirius` binary that is launched by the system's application launcher or via the terminal, or any other way.

# Architecture
This can probably be expanded in the future to take away certain responsibilities from the Renderer process to smaller, specialized ones, but I'm currently following the path of minimum suffering.

At its core, the following processes are run per tab (we do not support tabbed browsing as of yet, but it probably shouldn't be an afterthought :P):

## 1. Renderer
This is the main process spawned per tab. It is responsible for:
- Parsing HTML into the DOM
- Parsing CSS
- Calculating layout and style
- Executing JavaScript
- Rendering the webpage
- Handling network requests (**TODO**: Move this into the process belowand let the master process handle chatter between the two)

## 2. Network
**Note**: For now, this does not exist, but it is a goal to implement this.

As the name suggests, this process would be responsible for a singular task: handling all tasks related to networking for this tab.

# Zygote
When the master


