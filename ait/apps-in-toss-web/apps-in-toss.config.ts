import { defineConfig } from '@apps-in-toss/web-framework/config'

export default defineConfig({
  appName: 'foam-party',

  brand: {
    primaryColor: '#81c5c3'
  },

  permissions: [],
  webBundleDir: 'dist',

  webView: {
    overScrollMode: 'never'
  }
})
