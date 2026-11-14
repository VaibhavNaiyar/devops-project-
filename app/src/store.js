// Storage: DynamoDB on AWS (TABLE_NAME set, credentials from the EC2 instance role), in-memory locally / in tests.
const crypto = require('crypto');

function memoryStore() {
  const items = new Map();
  return {
    kind: 'memory',
    async list() { return [...items.values()].sort((a, b) => b.createdAt.localeCompare(a.createdAt)); },
    async get(id) { return items.get(id) || null; },
    async put(item) { items.set(item.id, item); return item; },
  };
}

function dynamoStore(table, region) {
  const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
  const { DynamoDBDocumentClient, ScanCommand, GetCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');
  const db = DynamoDBDocumentClient.from(new DynamoDBClient({ region }));
  return {
    kind: 'dynamodb',
    async list() {
      const out = await db.send(new ScanCommand({ TableName: table, Limit: 200 }));
      return (out.Items || []).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    },
    async get(id) { return (await db.send(new GetCommand({ TableName: table, Key: { id } }))).Item || null; },
    async put(item) { await db.send(new PutCommand({ TableName: table, Item: item })); return item; },
  };
}

function createStore(env = process.env) {
  return env.TABLE_NAME ? dynamoStore(env.TABLE_NAME, env.AWS_REGION || 'us-east-1') : memoryStore();
}

const newId = () => crypto.randomUUID().slice(0, 8);
module.exports = { createStore, memoryStore, newId };
