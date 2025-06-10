import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import native from 'naive-ui'
import ElementPlus from 'element-plus';
import 'element-plus/dist/index.css';

createApp(App)
  .use(router)
  .use(native)
  .use(ElementPlus)
  .mount('#app')
