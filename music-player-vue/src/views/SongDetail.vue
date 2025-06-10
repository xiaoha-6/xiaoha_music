<template>
  <div class="song-detail">
    <div class="back-button" @click="goBack">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path d="M19 12H5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
        <path d="M12 19L5 12L12 5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </div>
    <div class="song-container">
      <div class="cover-section">
        <div class="cover-wrapper" :class="coverClasses">
          <img :src="currentMusic.avatar" alt="album cover" />
        </div>
      </div>
      <div class="info-section">
        <h2>{{ currentMusic.name }}</h2>
        <p>{{ getArtistName() }}</p>
      </div>
      <div class="lyric-container" ref="lyricRef">
        <div class="lyric-wrapper">
          <div 
            class="lyric-content"
            :style="{ transform: `translateY(${translateY}px)` }"
          >
            <template v-if="parsedLyrics.length > 0">
              <p 
                v-for="(lyric, index) in parsedLyrics" 
                :key="index"
                :class="{ 'active': index === currentLyricIndex }"
              >
                {{ lyric.text }}
              </p>
            </template>
            <p v-else class="no-lyric">暂无歌词</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, computed, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { currentMusic, isPlaying, isPaused, audioElement } from '../store/music'

const router = useRouter()
const lyricRef = ref(null)
const currentTime = ref(0)
const currentLyricIndex = ref(0)
const translateY = ref(0)
const parsedLyrics = ref([])

const coverClasses = computed(() => ({
  'is-playing': isPlaying.value,
  'is-paused': isPaused.value
}))

// 解析歌词时间
const parseLyricTime = (timeStr) => {
  const [min, sec] = timeStr.split(':')
  const [seconds, milliseconds] = sec.split('.')
  return parseInt(min) * 60 + parseInt(seconds) + (parseInt(milliseconds || 0) / 100)
}

// 解析歌词内容
const parseLyrics = (text) => {
  if (!text) return []
  
  const lines = text.split('\n')
  const lyrics = []
  
  lines.forEach(line => {
    // 匹配[xx:xx.xx]格式的时间戳
    const timeRegex = /\[(\d{2}:\d{2}(?:\.\d{2})?)\]/g
    const textContent = line.replace(timeRegex, '').trim()
    
    if (!textContent) return
    
    let match
    while ((match = timeRegex.exec(line)) !== null) {
      const time = parseLyricTime(match[1])
      lyrics.push({ time, text: textContent })
    }
  })
  
  return lyrics.sort((a, b) => a.time - b.time)
}

// 获取歌词
const fetchLyrics = async () => {
  if (!currentMusic.value?.id) return

  try {
    // 使用新的API获取歌曲详情
    const response = await fetch(`https://api.qijieya.cn/meting/?type=song&id=${currentMusic.value.id}`)
    const data = await response.json()
    
    if (data && data.lyric) {
      parsedLyrics.value = parseLyrics(data.lyric)
      console.log('获取到歌词:', parsedLyrics.value)

      // 更新歌曲信息
      if (data.title && data.author) {
        currentMusic.value = {
          ...currentMusic.value,
          name: data.title,
          singer: data.author,
          avatar: data.pic || currentMusic.value.avatar,
          ar: [{ name: data.author }]
        }
      }
    } else {
      console.log('未获取到歌词数据')
      parsedLyrics.value = []
      
      // 如果未获取到歌词，尝试直接从URL获取歌词
      if (currentMusic.value.lrc) {
        const lrcResponse = await fetch(currentMusic.value.lrc)
        const lrcText = await lrcResponse.text()
        if (lrcText) {
          parsedLyrics.value = parseLyrics(lrcText)
          console.log('从URL获取到歌词:', parsedLyrics.value)
        }
      }
    }
  } catch (error) {
    console.error('获取歌词失败:', error)
    parsedLyrics.value = []
  }
}

// 更新当前歌词
const updateLyric = () => {
  if (!audioElement || !parsedLyrics.value.length) return
  
  const time = audioElement.currentTime
  currentTime.value = time

  // 查找当前时间对应的歌词
  const index = parsedLyrics.value.reduce((prev, curr, idx) => {
    if (curr.time <= time) return idx
    return prev
  }, 0)

  if (currentLyricIndex.value !== index) {
    currentLyricIndex.value = index
    
    // 计算滚动位置
    const lineHeight = 32
    const containerHeight = lyricRef.value?.clientHeight || 0
    const targetY = -index * lineHeight + containerHeight / 2 - lineHeight / 2
    
    // 平滑滚动
    translateY.value = targetY
  }
}

// 监听播放时间更新
watch(() => currentMusic.value.id, () => {
  fetchLyrics()
  currentLyricIndex.value = 0
  translateY.value = 0
}, { immediate: true })

onMounted(() => {
  if (audioElement) {
    audioElement.addEventListener('timeupdate', updateLyric)
  }
})

onUnmounted(() => {
  if (audioElement) {
    audioElement.removeEventListener('timeupdate', updateLyric)
  }
})

const goBack = () => {
  router.back()
}

// 获取艺术家名称
const getArtistName = () => {
  if (currentMusic.value.ar && currentMusic.value.ar[0]) {
    return currentMusic.value.ar[0].name
  } else if (currentMusic.value.singer) {
    return currentMusic.value.singer
  } else if (currentMusic.value.artist) {
    return currentMusic.value.artist
  }
  return '未知艺术家'
}
</script>

<style scoped>
.song-detail {
  position: absolute;
  top: 0;
  left: 320px;
  right: 0;
  height: calc(100% - 118px);
  background: #1a1a1a;
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1;
}

.song-container {
  width: 100%;
  height: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 10px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  color: #fff;
}

.cover-section {
  margin-top: 0;
  display: flex;
  justify-content: center;
  flex-shrink: 0;
}

.cover-wrapper {
  width: 130px;
  height: 130px;
  border-radius: 50%;
  overflow: hidden;
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.3);
  border: 3px solid rgba(255, 255, 255, 0.1);
  flex-shrink: 0;
  transform-origin: center center;
}

.cover-wrapper.is-playing {
  animation: rotate 20s linear infinite;
  animation-play-state: running;
}

.cover-wrapper.is-paused {
  animation: rotate 20s linear infinite;
  animation-play-state: paused;
}

@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.info-section {
  text-align: center;
  width: 100%;
  flex-shrink: 0;
  margin-top: -8px;
}

.info-section h2 {
  font-size: 18px;
  margin: 0 0 6px 0;
  color: #fff;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: 0 20px;
}

.info-section p {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.7);
  margin: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.lyric-container {
  flex: 1;
  width: 100%;
  position: relative;
  padding: 0 20px;
  overflow: hidden;
  min-height: 300px;
  display: flex;
  align-items: center;
}

.lyric-wrapper {
  width: 100%;
  height: 100%;
  overflow: hidden;
  position: relative;
  mask-image: linear-gradient(180deg, transparent 0%, #fff 25%, #fff 75%, transparent 100%);
  -webkit-mask-image: linear-gradient(180deg, transparent 0%, #fff 25%, #fff 75%, transparent 100%);
}

.lyric-content {
  position: absolute;
  width: 100%;
  text-align: center;
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  will-change: transform;
}

.lyric-content p {
  height: 32px;
  line-height: 32px;
  padding: 0;
  margin: 0;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.5);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  transform-origin: center center;
}

.lyric-content p.active {
  color: #fff;
  font-size: 16px;
  font-weight: 500;
  transform: scale(1.1);
}

.no-lyric {
  color: rgba(255, 255, 255, 0.5);
  font-size: 14px;
  text-align: center;
  padding: 20px 0;
}

.back-button {
  position: absolute;
  top: 20px;
  left: 20px;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.7);
  cursor: pointer;
  transition: color 0.3s ease;
  z-index: 2;
}

.back-button:hover {
  color: #fff;
}

.back-button svg {
  width: 100%;
  height: 100%;
}

img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

@media screen and (max-width: 768px) {
  .song-detail {
    left: 60px;
  }

  .song-container {
    padding: 10px;
  }

  .cover-wrapper {
    width: 120px;
    height: 120px;
  }

  .info-section h2 {
    font-size: 16px;
  }

  .info-section p {
    font-size: 12px;
  }

  .lyric-content p {
    height: 22px;
    line-height: 22px;
    font-size: 12px;
  }

  .lyric-content p.active {
    font-size: 14px;
  }
}
</style>
