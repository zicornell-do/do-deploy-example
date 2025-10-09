import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { Module, Controller, Get } from '@nestjs/common';

@Controller()
class AppController {
  @Get('/')
  getRoot(): string {
    return 'Hello, World!';
  }

  @Get('/health')
  getHealth(): string {
    return 'OK';
  }
}

@Module({
  controllers: [AppController],
})
class AppModule {}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const port = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`some-service listening on http://localhost:${port}`);
}

bootstrap().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start application', err);
  process.exit(1);
});
