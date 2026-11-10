import { HttpContext, ExceptionHandler } from '@adonisjs/core/http'
import type { StatusPageRange, StatusPageRenderer } from '@adonisjs/core/types/http'

export default class HttpExceptionHandler extends ExceptionHandler {
  protected debug = false

  protected renderStatusPages = false

  protected statusPages: Record<StatusPageRange, StatusPageRenderer> = {}

  async handle(error: any, ctx: HttpContext) {
    const status = error.status || 500
    const message = error.message || 'Internal Server Error'

    return ctx.response.status(status).json({
      error: error.name || 'Error',
      message,
      statusCode: status,
    })
  }

  async report(error: any, ctx: HttpContext) {
    return super.report(error, ctx)
  }
}
