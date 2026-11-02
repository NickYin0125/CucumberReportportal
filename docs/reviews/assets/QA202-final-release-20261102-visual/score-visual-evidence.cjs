const fs = require('node:fs');
const path = require('node:path');
const dir = __dirname;
const read = name => JSON.parse(fs.readFileSync(path.join(dir, name + '.json'), 'utf8'));
const manifest = read('visual-input-manifest-final');
const logs = manifest.entries.flatMap(e => e.logs);
const foldGroups = [
  ['S18-340-lines-open', [22312, 22313], [0]],
  ['S18-json-open', [22312, 22313], [1]],
  ['S18-docstring-open', [22320], [0]],
  ['S09-http-info-headers-open', [22331], [0, 1]],
  ['S09-http-all-folds-open', [22353, 22354, 22355, 22356, 22357, 22358], Array.from({ length: 12 }, (_, i) => i)],
  ['S09-http-40-lines-open', [22327], [0, 1]]
];
const foldChecks = [];
for (const [capture, ids, indexes] of foldGroups) {
  const evidence = read(capture);
  const expected = ids.flatMap(id => logs.find(l => l.id === id).folds.map(f => ({ ...f, logId: id })));
  if (evidence.details.length !== expected.length) throw new Error('Fold inventory mismatch: ' + capture);
  for (const index of indexes) {
    const actual = evidence.details[index];
    const raw = expected[index];
    const match = raw.rawBody.match(/^\n\n(`{3,}|~{3,})([^\n]*)\n([\s\S]*)\n\1\n\n$/);
    foldChecks.push({ capture, launchId: evidence.launchId, logId: raw.logId,
      summary: actual.summary, rawSummary: raw.summary,
      rawBlankLines: raw.blankBeforeAndAfterFence,
      open: actual.open, directPreCodeCount: actual.directPreCodeCount,
      exactCodeText: Boolean(match && actual.codes.length === 1 && actual.codes[0].text === match[3]),
      parent: actual.codes[0]?.parent, grandparent: actual.codes[0]?.grandparent });
  }
}
const toneSources = [
  ['PASS', 'S09-passed-assertion', 'PASS', 4059, 33158, 22336],
  ['FAIL', 'S09-http-tones-closed', '500', 4064, 33177, 22355],
  ['WARN', 'S09-http-tones-closed', '404', 4064, 33177, 22354],
  ['INFO', 'S06-rich-media', 'PNG', 4061, 33166, 22339]
];
const rgb = text => {
  const values = text.match(/[\d.]+/g).map(Number);
  if (values.length === 4 && values[3] !== 1) throw new Error('Non-opaque color needs compositing');
  return values.slice(0, 3);
};
const luminance = text => rgb(text).map(v => v / 255).map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)
  .reduce((sum, value, i) => sum + value * [0.2126, 0.7152, 0.0722][i], 0);
const contrast = toneSources.map(([tone, capture, label, launchId, itemId, logId]) => {
  const pill = read(capture).styledSpans.find(s => s.text === label && s.inlineStyle.includes('border-radius'));
  if (!pill) throw new Error('Pill missing: ' + tone);
  const a = luminance(pill.foreground), b = luminance(pill.background);
  return { tone, capture, launchId, itemId, logId, logLevel: logs.find(l => l.id === logId).level,
    foreground: pill.foreground, background: pill.background,
    allAncestorOpacityOne: pill.ancestorPaint.every(a => a.opacity === '1'),
    ratio: (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05), minimum: 4.5 };
});
const literalChecks = [
  ['P16-script-literal', 'x<script>alert(1)</script>', 22278],
  ['P16-bold-literal', '<b>x</b>', 22269]
].map(([capture, literal, logId]) => {
  const e = read(capture);
  const heading = e.headings.find(h => h.text.includes(literal));
  // The saved RP log wrapper contains h2/p/pre, with no nested div wrappers.
  // Scope to that captured wrapper, excluding the page's legitimate analytics script.
  const scopedHTML = e.rootHTML.match(/<div class="[^"]*logMessageBlock__markdown-viewer--lbWFI[^"]*">([\s\S]*?)<\/div>/)?.[1];
  if (!scopedHTML) throw new Error('Saved rendered log root missing: ' + capture);
  return { capture, launchId: e.launchId, itemIds: e.itemIds, logId, literal,
    exactHeading: heading?.text === '✗ RuntimeError: ' + literal,
    scopedHTML,
    scriptCount: [...scopedHTML.matchAll(/<script(?:\s|>)/gi)].length,
    boldElementCount: [...scopedHTML.matchAll(/<b(?:\s|>)/gi)].length };
});
const errorPlainPairs = logs.filter(l => ['error', 'fatal'].includes(l.level)).map(l => ({
  richLogId: l.id, plainLogId: l.plainLogId, launchId: l.launchId, level: l.level,
  richMessageSHA256: l.messageSHA256, plainMessageSHA256: l.plainMessageSHA256,
  equal: l.byteIdenticalToPlain
}));
const result = { candidate: manifest.candidate, generatedAt: new Date().toISOString(),
  literalChecks, foldChecks, contrast, errorPlainPairs,
  foldTotal: foldChecks.length,
  rawFoldTotal: logs.reduce((count, log) => count + log.folds.length, 0),
  allFoldsPass: foldChecks.every(f => f.open && f.rawBlankLines && f.summary === f.rawSummary && f.directPreCodeCount === 1 && f.exactCodeText && f.parent === 'PRE' && f.grandparent === 'DETAILS'),
  allContrastPass: contrast.every(c => c.ratio >= c.minimum && c.allAncestorOpacityOne && !['error', 'fatal'].includes(c.logLevel)),
  allLiteralChecksPass: literalChecks.every(c => c.exactHeading && c.scriptCount === 0 && c.boldElementCount === 0),
  allInspectedErrorFatalPairsEqual: errorPlainPairs.every(p => p.equal === true)
};
fs.writeFileSync(path.join(dir, 'visual-check-results.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ foldTotal: result.foldTotal, rawFoldTotal: result.rawFoldTotal,
  allFoldsPass: result.allFoldsPass, allLiteralChecksPass: result.allLiteralChecksPass,
  contrast, allContrastPass: result.allContrastPass,
  errorFatalPairCount: errorPlainPairs.length, allInspectedErrorFatalPairsEqual: result.allInspectedErrorFatalPairsEqual,
  failedFolds: foldChecks.filter(f => !f.exactCodeText || !f.rawBlankLines || !f.open)
}, null, 2));
