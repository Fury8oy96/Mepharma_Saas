import { defineConfig } from '@adonisjs/core/bodyparser'

const bodyParserConfig = defineConfig({
  json: {
    encoding: 'utf-8',
    limit: '20mb',
    strict: true,
    types: [
      'application/json',
      'application/json-patch+json',
      'application/vnd.api+json',
      'application/csp-report',
    ],
  },
  form: {
    encoding: 'utf-8',
    limit: '10mb',
    queryString: {},
    types: ['application/x-www-form-urlencoded'],
  },
  raw: {
    encoding: 'utf-8',
    limit: '20mb',
    types: ['text/*'],
  },
  multipart: {
    autoProcess: true,
    maxFields: 1000,
    processManually: [],
    encoding: 'utf-8',
    convertEmptyStringsToNull: true,
    types: ['multipart/form-data'],
  },
})

export default bodyParserConfig
