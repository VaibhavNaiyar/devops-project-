const { buildApp } = require('./app');

const port = Number(process.env.PORT || 8080);
const server = buildApp().listen(port, () => console.log(JSON.stringify({ level: 'info', msg: `CampusDesk ${process.env.APP_VERSION || 'dev'} listening on ${port}` })));

// Graceful shutdown: finish in-flight requests when Docker stops the container during a rolling deploy
for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => server.close(() => process.exit(0)));
}
