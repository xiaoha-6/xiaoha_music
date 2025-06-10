import { ref } from 'vue'

// 默认图片配置
const defaultImages = {
  notPlaying: 'https://pic1.imgdb.cn/item/67ba5000d0e0a243d4025664.png',
  paused: 'https://pic1.imgdb.cn/item/67ba504dd0e0a243d4025680.png',
  playing: 'https://pic1.imgdb.cn/item/67ba504dd0e0a243d4025680.jpg'
}

export const currentMusic = ref({
  id: '',
  avatar: defaultImages.notPlaying,
  name: '未播放',
  singer: '',
  album: '',
  duration: '',
  djTableId: ''
})

export const isPlaying = ref(false)
export const isPaused = ref(false)

// 更新播放状态和头像
export const updatePlayingState = (state) => {
  isPlaying.value = state === 'playing'
  isPaused.value = state === 'paused'
  
  if (currentMusic.value.id) { // 只有在有音乐时才改变头像
    if (state === 'playing' && !currentMusic.value.avatar.includes('http')) {
      currentMusic.value.avatar = defaultImages.playing
    } else if (state === 'paused' && !currentMusic.value.avatar.includes('http')) {
      currentMusic.value.avatar = defaultImages.paused
    }
  }
}
