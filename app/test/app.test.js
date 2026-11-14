const test = require('node:test');
const assert = require('node:assert');
const { buildApp } = require('../src/app');
const { memoryStore } = require('../src/store');

async function start() {
  const server = buildApp({ store: memoryStore(), version: 'test' }).listen(0);
  await new Promise((r) => server.once('listening', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = (p, opts = {}) => fetch(base + p, { ...opts, headers: { 'Content-Type': 'application/json' } });
  return { server, call };
}

test('health reports UP with version', async () => {
  const { server, call } = await start();
  const body = await (await call('/health')).json();
  assert.strictEqual(body.status, 'UP');
  assert.strictEqual(body.version, 'test');
  server.close();
});

test('create, list and update a request', async () => {
  const { server, call } = await start();
  const created = await call('/api/requests', { method: 'POST', body: JSON.stringify({ title: 'Wi-Fi down in Block C', category: 'IT', location: 'C-204' }) });
  assert.strictEqual(created.status, 201);
  const item = await created.json();
  assert.strictEqual(item.status, 'Open');
  const list = await (await call('/api/requests')).json();
  assert.strictEqual(list.length, 1);
  const upd = await call(`/api/requests/${item.id}`, { method: 'PATCH', body: JSON.stringify({ status: 'Resolved' }) });
  assert.strictEqual((await upd.json()).status, 'Resolved');
  server.close();
});

test('rejects invalid input', async () => {
  const { server, call } = await start();
  const bad = await call('/api/requests', { method: 'POST', body: JSON.stringify({ title: 'x', category: 'Food' }) });
  assert.strictEqual(bad.status, 400);
  assert.strictEqual((await bad.json()).errors.length, 2);
  const badStatus = await call('/api/requests/nope', { method: 'PATCH', body: JSON.stringify({ status: 'Done' }) });
  assert.strictEqual(badStatus.status, 400);
  const missing = await call('/api/requests/nope', { method: 'PATCH', body: JSON.stringify({ status: 'Resolved' }) });
  assert.strictEqual(missing.status, 404);
  server.close();
});

test('sets security headers and hides x-powered-by', async () => {
  const { server, call } = await start();
  const r = await call('/health');
  assert.strictEqual(r.headers.get('x-content-type-options'), 'nosniff');
  assert.strictEqual(r.headers.get('x-powered-by'), null);
  server.close();
});
