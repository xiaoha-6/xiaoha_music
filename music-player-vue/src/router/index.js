import { createRouter, createWebHashHistory } from 'vue-router'
import Recent from '../views/Recent.vue'
import SongDetail from '../views/SongDetail.vue'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: ()=>import('../views/Home.vue')
  },
  {
    path: '/find',
    name: 'find',
    component: ()=>import('../views/DiscoveringMusic.vue')
  },
  {
    path: '/recent',
    name: 'Recent',
    component: Recent
  },
  {
    path: '/song/:id',
    name: 'SongDetail',
    component: SongDetail
  },
  {
    path: '/playlist/:id',
    name: 'PlaylistDetail',
    component: () => import('../views/PlaylistDetail.vue')
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

export default router
