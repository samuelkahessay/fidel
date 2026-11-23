/** Registers the bundled Noto Sans Ethiopic font (WOFF2, built from the app's TTF) under the site's base path. */
export function registerFonts() {
  const style = document.createElement('style')
  style.textContent =
    `@font-face{font-family:'Noto Sans Ethiopic';src:url('${import.meta.env.BASE_URL}fonts/NotoSansEthiopic.woff2') format('woff2');` +
    `font-display:swap;unicode-range:U+1200-139F,U+2D80-2DDF,U+AB00-AB2F}`
  document.head.append(style)
}
