const express = require('express');
const os = require('os');
const path = require('path');
const { createStore, newId } = require('./store');

const CATEGORIES = ['Hostel', 'Lab', 'IT', 'Library', 'Other'];
const STATUSES = ['Open', 'In progress', 'Resolved'];

// Release colour: change it together with the version in package.json to see a release go live in the browser
const RELEASE_COLOR = '#2563eb';

function buildApp({
  store = createStore(),
  version = process.env.APP_VERSION || 'dev',
  color = process.env.APP_COLOR || RELEASE_COLOR,
  // Fault injection for the rollback demo: the container starts but reports itself unhealthy
  failHealth = process.env.FAIL_HEALTH === '1',
} = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '10kb' }));
  app.use((req, res, next) => {
    res.set({ 'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY', 'Referrer-Policy': 'no-referrer' });
    next();
  });

  // Health check used by the ALB, the Jenkins smoke test and the zero-downtime watcher
  app.get('/health', (req, res) => res.status(failHealth ? 503 : 200)
    .json({ status: failHealth ? 'DOWN' : 'UP', version, host: os.hostname(), store: store.kind }));
  app.get('/api/info', (req, res) => res.json({ version, color, host: os.hostname(), categories: CATEGORIES, statuses: STATUSES }));

  app.get('/api/requests', async (req, res, next) => {
    try { res.json(await store.list()); } catch (e) { next(e); }
  });

  app.post('/api/requests', async (req, res, next) => {
    const { title, category, location } = req.body || {};
    const errors = [];
    if (typeof title !== 'string' || title.trim().length < 3 || title.length > 120) errors.push('title must be 3-120 characters');
    if (!CATEGORIES.includes(category)) errors.push(`category must be one of ${CATEGORIES.join(', ')}`);
    if (location !== undefined && (typeof location !== 'string' || location.length > 60)) errors.push('location must be at most 60 characters');
    if (errors.length) return res.status(400).json({ errors });
    try {
      const item = { id: newId(), title: title.trim(), category, location: (location || '').trim(), status: 'Open', createdAt: new Date().toISOString() };
      res.status(201).json(await store.put(item));
    } catch (e) { next(e); }
  });

  app.patch('/api/requests/:id', async (req, res, next) => {
    const { status } = req.body || {};
    if (!STATUSES.includes(status)) return res.status(400).json({ errors: [`status must be one of ${STATUSES.join(', ')}`] });
    try {
      const item = await store.get(req.params.id);
      if (!item) return res.status(404).json({ errors: ['request not found'] });
      res.json(await store.put({ ...item, status, updatedAt: new Date().toISOString() }));
    } catch (e) { next(e); }
  });

  app.use(express.static(path.join(__dirname, '..', 'public')));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(JSON.stringify({ level: 'error', msg: err.message, path: req.path }));
    res.status(500).json({ errors: ['internal error'] });
  });
  return app;
}

module.exports = { buildApp, CATEGORIES, STATUSES };
