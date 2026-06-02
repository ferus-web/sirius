# Running Sirius
Sirius as a binary is simply using the inner `WebView` logic, which in turn is just an orchestration layer for all the different components in `components/`.

If you wish to navigate to a file, you must use the `file://` scheme, with either an absolute or relative path to the target.

If you wish to navigate to a networked resource, you must supply the correct scheme (`https` or `http`) as well as the rest of the URL.

## WebViewOpts
These let you control the `WebView`'s behavior in loading certain content.

### `--disable-image-loading`
This prevents the engine from fetching images over the network at all. All images will simply refuse to render.

### `--disable-external-stylesheets`
This prevents the engine from fetching external stylesheets (`<link rel="stylesheet" ...>`). As many sites use CSS syntax that the parser deadlocks upon seeing, this often prevents said hangups from occurring. It's a temporary hack while Sirius' CSS3 parser evolves and improves.

### `--disable-styling`
This prevents the engine from parsing **ANY** CSS styling in the document, including `<style>` tags. All styling, in turn, will be derived from Sirius' base User Agent CSS. It is the final resort to fixing a hangup if the CSS parser chokes on some inline styling.
