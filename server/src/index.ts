import net from 'net';
import path from 'path';
import fs from 'fs';
import prettier from 'prettier';

const server = net.createServer((conn: net.Socket) => {
  console.log('new connection', conn.remoteAddress);

  conn.on('data', (msg: any) => {
    const [id, data] = JSON.parse(msg);
    console.log(data);

    resolveConfig(data.path).then(options => {
      const result = prettier.format(data.source, { ...options, parser: 'typescript' });
      conn.write(JSON.stringify([id, { source: result }]));
    });
  });

  conn.on('close', () => {
    console.log('close');
  });
});

server.listen(4242);

const resolveConfig = async (filePath: string | undefined): Promise<object> => {
  if (filePath) {
    return prettier.resolveConfig(filePath).then(options => options || {});
  }
  return {};
};
