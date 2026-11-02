const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const out = __dirname;
const base = path.resolve(out, '../QA202-final-release-20261102-contract');
const sha = '8f44c10533eb4d0a8eae1adcc2ed5b63ace155c7';
const names = ['F14', 'F14-negative', 'F18', 'F01', 'F10a', 'F11a', 'F12', 'QA202-values', 'QA202-http', 'QA202-captions', 'F13', 'F03', 'F11b', 'F11e', 'F04', 'F04-frozen'];
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const entries = [];
for (const name of names) {
  const group = name === 'F13' ? 'p1-rich' : 'fixtures-rich-v3';
  const dir = path.join(base, group, name);
  if (!fs.existsSync(path.join(dir, 'snapshot.json'))) continue;
  const bytes = fs.readFileSync(path.join(dir, 'snapshot.json'));
  const resultBytes = fs.readFileSync(path.join(dir, 'result.json'));
  const snapshot = JSON.parse(bytes);
  const result = JSON.parse(resultBytes);
  if (result.source_sha !== sha) throw new Error('Candidate mismatch: ' + name);
  const plainFile = path.join(base, name === 'F13' ? 'p1-plain' : 'fixtures-plain-v3', name, 'snapshot.json');
  const plainBytes = fs.existsSync(plainFile) ? fs.readFileSync(plainFile) : null;
  const plain = plainBytes ? JSON.parse(plainBytes) : null;
  const itemKey = (item, items) => {
    const ids = item.path.split('.').map(Number);
    return ids.map(id => items.find(i => i.id === id)?.name).join('/');
  };
  const logs = snapshot.logs.map(log => {
    const item = snapshot.items.find(i => i.id === log.itemId);
    const sameItemLogs = snapshot.logs.filter(l => l.itemId === log.itemId);
    const index = sameItemLogs.findIndex(l => l.id === log.id);
    const plainItem = plain?.items.find(i => itemKey(i, plain.items) === itemKey(item, snapshot.items));
    const plainLog = plain?.logs.filter(l => l.itemId === plainItem?.id)[index];
    const folds = [...log.message.matchAll(/<details><summary>(.*?)<\/summary>([\s\S]*?)<\/details>/g)].map(m => ({
      summary: m[1],
      rawBody: m[2],
      blankBeforeAndAfterFence: /^\n\n(`{3,}|~{3,})[^\n]*\n[\s\S]*\n\1\n\n$/.test(m[2])
    }));
    return {
      id: log.id, itemId: log.itemId, itemName: item?.name, itemPath: item?.path,
      launchId: item?.launchId, level: log.level,
      messageSHA256: hash(log.message), firstLine: log.message.split('\n')[0],
      plainLogId: plainLog?.id, plainMessageSHA256: plainLog && hash(plainLog.message),
      byteIdenticalToPlain: plainLog ? log.message === plainLog.message : null,
      message: log.message, folds
    };
  });
  entries.push({ name, candidate: result.source_sha, mode: result.mode,
    source: path.join(dir, 'snapshot.json'), sourceSHA256: hash(bytes),
    resultSource: path.join(dir, 'result.json'), resultSourceSHA256: hash(resultBytes),
    plainSource: plainBytes ? plainFile : null, plainSourceSHA256: plainBytes && hash(plainBytes),
    launchIds: result.launch_ids, items: snapshot.items.map(i=>({id:i.id,name:i.name,path:i.path,launchId:i.launchId})), logs });
}
const manifest = { candidate: sha, generatedAt: new Date().toISOString(), entries };
fs.writeFileSync(path.join(out, process.argv[2] || 'visual-input-manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify(entries.map(e=>({fixture:e.name, launches:e.launchIds,
  logs:e.logs.map(l=>({id:l.id,item:l.itemId,level:l.level,title:l.firstLine.slice(0,110),folds:l.folds.map(f=>f.summary)}))})),null,2));
