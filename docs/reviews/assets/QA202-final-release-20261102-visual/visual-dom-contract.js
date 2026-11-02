(options) => {
  const root = document.querySelector(options.rootSelector);
  if (!root) throw new Error("Evidence root not found: " + options.rootSelector);
  const rect = (element) => {
    const r = element.getBoundingClientRect();
    return { x: r.x, y: r.y, width: r.width, height: r.height };
  };
  const chain = (element) => {
    const result = [];
    for (let node = element; node; node = node.parentElement) {
      const style = getComputedStyle(node);
      result.push({
        tag: node.tagName,
        className: node.className,
        foreground: style.color,
        background: style.backgroundColor,
        opacity: style.opacity,
        backgroundImage: style.backgroundImage
      });
    }
    return result;
  };
  return {
    capturedAt: new Date().toISOString(),
    url: location.href,
    title: document.title,
    viewport: { width: innerWidth, height: innerHeight, devicePixelRatio },
    rootSelector: options.rootSelector,
    rootHTML: root.outerHTML,
    rootTextContent: root.textContent,
    rootInnerText: root.innerText,
    renderedLogs: [...root.querySelectorAll('.logMessageBlock__markdown-viewer--lbWFI')].map((node) => ({
      html: node.outerHTML,
      text: node.textContent,
      headings: [...node.querySelectorAll('h2')].map(h => ({ text: h.textContent, html: h.outerHTML })),
      scriptCount: node.querySelectorAll('script').length,
      boldElementCount: node.querySelectorAll('b').length
    })),
    headings: [...root.querySelectorAll("h1,h2,h3")].map((node) => ({
      tag: node.tagName, text: node.textContent, html: node.outerHTML, rect: rect(node)
    })),
    injectedNodeCandidates: [...root.querySelectorAll("script,b")].map((node) => ({
      tag: node.tagName, html: node.outerHTML
    })),
    details: [...root.querySelectorAll("details")].map((node, index) => ({
      index,
      open: node.open,
      summary: node.querySelector("summary")?.textContent,
      directChildren: [...node.children].map((child) => child.tagName),
      directPreCodeCount: node.querySelectorAll(":scope > pre > code").length,
      descendantPreCodeCount: node.querySelectorAll("pre > code").length,
      codes: [...node.querySelectorAll("code")].map((code) => ({
        text: code.textContent,
        parent: code.parentElement.tagName,
        grandparent: code.parentElement.parentElement?.tagName,
        className: code.className,
        rect: rect(code)
      })),
      html: node.outerHTML,
      rect: rect(node)
    })),
    styledSpans: [...root.querySelectorAll("span[style]")].map((node) => {
      const style = getComputedStyle(node);
      return {
        text: node.textContent,
        inlineStyle: node.getAttribute("style"),
        foreground: style.color,
        background: style.backgroundColor,
        display: style.display,
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        lineHeight: style.lineHeight,
        borderRadius: style.borderRadius,
        rect: rect(node),
        ancestorPaint: chain(node)
      };
    }),
    tables: [...root.querySelectorAll("table")].map((table) => ({
      html: table.outerHTML,
      rows: [...table.rows].map((row) => [...row.cells].map((cell) => ({
        text: cell.textContent,
        textAlign: getComputedStyle(cell).textAlign
      })))
    }))
  };
}
