const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  lintOnSave: false,
  publicPath: './', // 添加相对路径配置，使打包后的文件支持直接打开index.html
  devServer: {
    proxy: {
      '/api': {
        target: 'https://music.163.com',
        changeOrigin: true,
        pathRewrite: {
          '^/api': ''
        }
      }
    }
  },
  configureWebpack: {
    resolve: {
      fallback: {
        "fs": require.resolve("fs"),
        "path": require.resolve("path")
      }
    }
  }
})
