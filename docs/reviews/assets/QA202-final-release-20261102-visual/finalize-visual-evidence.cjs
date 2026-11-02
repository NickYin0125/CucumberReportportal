const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const dir = __dirname;
const report = path.resolve(dir, '../../2026-11-02-final-release-visual-acceptance.md');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'visual-input-manifest-final.json')));
const captures = [];
for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.json'))) {
  const value = JSON.parse(fs.readFileSync(path.join(dir, file)));
  if (!value.screenshot) continue;
  const screenshotPath = path.join(dir, value.screenshot);
  const screenshotSHA256 = hash(fs.readFileSync(screenshotPath));
  if (screenshotSHA256 !== value.screenshotSHA256) throw new Error('Screenshot changed: ' + file);
  const sources = (value.logIds || []).map(id => {
    const entry = manifest.entries.find(e => e.logs.some(l => l.id === id || l.plainLogId === id));
    const log = entry?.logs.find(l => l.id === id || l.plainLogId === id);
    if (!entry || !log) throw new Error('No source for log ' + id);
    const isPlain = log.plainLogId === id;
    const source = isPlain ? entry.plainSource : entry.source;
    const sourceSHA256 = isPlain ? entry.plainSourceSHA256 : entry.sourceSHA256;
    if (hash(fs.readFileSync(source)) !== sourceSHA256) throw new Error('Source changed: ' + source);
    const resultSource = source.replace(/snapshot\.json$/, 'result.json');
    const result = JSON.parse(fs.readFileSync(resultSource));
    if (result.source_sha !== manifest.candidate) throw new Error('Wrong candidate: ' + resultSource);
    return { logId: id, messageSHA256: isPlain ? log.plainMessageSHA256 : log.messageSHA256,
      source, sourceSHA256, resultSource, resultSourceSHA256: hash(fs.readFileSync(resultSource)),
      candidate: result.source_sha, mode: result.mode };
  });
  captures.push({ file, evidenceSHA256: hash(fs.readFileSync(path.join(dir, file))),
    screenshot: value.screenshot, screenshotSHA256, candidate: value.candidate,
    launchId: value.launchId, focusedItemIds: value.itemIds, focusedLogIds: value.logIds,
    url: value.url, viewport: value.viewport, hasFullDOM: Boolean(value.rootHTML), sources });
}
fs.writeFileSync(path.join(dir, 'capture-index.json'), JSON.stringify({ candidate: manifest.candidate, captures }, null, 2) + '\n');
const files = [...fs.readdirSync(dir).map(f => path.join(dir, f)), report,
  path.join(dir, 'OWNED_FILES.txt'), path.join(dir, 'asset-inventory.json')];
const unique = [...new Set(files)].sort();
fs.writeFileSync(path.join(dir, 'OWNED_FILES.txt'), unique.join('\n') + '\n');
const inventory = unique.filter(f => !f.endsWith('/asset-inventory.json')).map(file => ({
  file, bytes: fs.statSync(file).size, sha256: hash(fs.readFileSync(file))
}));
const suspicious = inventory.filter(e => !e.file.endsWith('.jpg')).flatMap(e => {
  const text = fs.readFileSync(e.file, 'utf8');
  const patterns = [/SECRET123/, /Bearer\s+[A-Za-z0-9._-]{16,}/, /-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/];
  return patterns.some(p => p.test(text)) ? [e.file] : [];
});
// This narrow local check complements, and does not replace, Master's secret scan.
fs.writeFileSync(path.join(dir, 'asset-inventory.json'), JSON.stringify({
  candidate: manifest.candidate, generatedAt: new Date().toISOString(),
  verdict: 'ACCEPT', scope: ['P1.6', 'P1.8', 'P1.9', 'P10.8', 'P10.10', 'P10.11'],
  captureCount: captures.length, ownedFileCount: unique.length,
  selfHashExcluded: 'asset-inventory.json', suspiciousFileCount: suspicious.length,
  suspiciousFiles: suspicious, files: inventory
}, null, 2) + '\n');
console.log(JSON.stringify({ captureCount: captures.length, ownedFileCount: unique.length,
  suspiciousFileCount: suspicious.length, inventory: path.join(dir, 'asset-inventory.json'),
  exactFileList: path.join(dir, 'OWNED_FILES.txt') }, null, 2));
