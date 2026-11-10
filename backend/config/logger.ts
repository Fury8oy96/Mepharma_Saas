import env from '#start/env'
import { defineConfig, targets } from '@adonisjs/core/logger'

const loggerConfig = defineConfig({
  default: 'app',

  /**
   * The loggers list defines the loggers you want to use in your application.
   */
  loggers: {
    app: {
      enabled: true,
      name: env.get('APP_NAME', 'mepharma'),
      level: env.get('LOG_LEVEL', 'info'),
      transport: {
        targets: targets()
          .pushIf(!env.get('NODE_ENV') || env.get('NODE_ENV') === 'development', {
            target: 'pino-pretty',
          })
          .toArray(),
      },
    },
  },
})

export default loggerConfig

/**
 * Inferring types for the list of loggers configured in your application.
 */
declare module '@adonisjs/core/types' {
  export interface LoggersList extends InferLoggers<typeof loggerConfig> {}
}
