// Web part of the URL Scheme plugin. A page is the link that opened it, so the hash of the page address stands in for the links of the scheme: it holds the query of a link, such as "#url=https%3A%2F%2Fexample.com%2Fapp.zip", when the page loads and at every later change of the hash, which reaches the app as a link of the scheme of the plugin.
export default function load(context) {
    const open = () => {
        if (location.hash.length > 1) {
            context.openLink(`${context.config.scheme}://open?${location.hash.slice(1)}`);
        }
    };
    window.addEventListener("hashchange", open);
    open();
}
