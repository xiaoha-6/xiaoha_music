<template>
  <div class="recent-plays">
    <div class="header">
      <div class="title-section">
        <h2>最近播放</h2>
        <span class="subtitle">为你记录播放过的每一首歌</span>
      </div>
      <div class="filter-section">
        <n-select
          v-model:value="timeFilter"
          :options="timeFilterOptions"
          size="small"
          style="width: 120px"
        />
      </div>
    </div>

    <div class="music-list" v-if="recentPlays.length > 0">
      <div 
        v-for="(song, index) in recentPlays" 
        :key="index" 
        class="music-item"
        :class="{ 'is-playing': currentPlayingId === `${song.dj_table_id}_${song.song_name}` }"
      >
        <div class="item-index">{{ index + 1 }}</div>
        <div class="music-cover" @click="playMusic(song)">
          <img :src="song.song_avatar || 'default_avatar.png'" alt="cover">
          <div class="play-icon">
            <n-icon size="30" color="#fff">
              <PlayCircle />
            </n-icon>
          </div>
        </div>
        <div class="music-info">
          <div class="song-title text-ellipsis">{{ song.song_name }}</div>
          <div class="song-details">
            <span class="artist text-ellipsis">{{ song.song_artist }}</span>
            <span class="album text-ellipsis" v-if="song.song_album">· {{ song.song_album }}</span>
          </div>
        </div>
        <div class="play-info">
          <div class="play-time">{{ formatPlayTime(song.played_at) }}</div>
          <div class="duration">{{ song.song_duration }}</div>
        </div>
        <div class="actions">
          <n-button 
            quaternary 
            circle 
            size="small" 
            @click="playMusic(song)"
            :class="{ 'playing': currentPlayingId === `${song.dj_table_id}_${song.song_name}` }"
          >
            <template #icon>
              <n-icon>
                <PlayCircle v-if="currentPlayingId !== `${song.dj_table_id}_${song.song_name}`" />
                <PauseCircle v-else />
              </n-icon>
            </template>
          </n-button>
        </div>
      </div>
    </div>

    <div class="empty-state" v-else>
      <n-empty description="还没有播放记录">
        <template #icon>
          <n-icon size="40" color="#666">
            <MusicNote />
          </n-icon>
        </template>
      </n-empty>
    </div>

    <div class="pagination-wrapper">
      <div class="pagination-content">
        <div class="page-info">
          <span>{{ totalItems === 0 ? 0 : (page - 1) * pageSize + 1 }}-{{ Math.min(page * pageSize, totalItems) }}</span>
          <span class="separator">/</span>
          <span>{{ totalItems }}</span>
        </div>
        <div class="page-controls">
          <n-button 
            quaternary 
            circle 
            size="small"
            :disabled="page === 1"
            @click="handlePageChange(page - 1)"
          >
            <template #icon>
              <n-icon><ChevronBack /></n-icon>
            </template>
          </n-button>
          <span class="current-page">{{ page }}</span>
          <n-button 
            quaternary 
            circle 
            size="small"
            :disabled="page >= Math.ceil(totalItems/pageSize)"
            @click="handlePageChange(page + 1)"
          >
            <template #icon>
              <n-icon><ChevronForward /></n-icon>
            </template>
          </n-button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, nextTick, onUnmounted } from 'vue'
import { currentMusic } from '../store/music'
import { NIcon, NButton } from 'naive-ui'
import { PlayCircle, MusicNote, PauseCircle, ChevronBack, ChevronForward } from '@vicons/ionicons5'

const recentPlays = ref([])
const page = ref(1)
const pageSize = ref(6)
const totalItems = ref(0)
const timeFilter = ref('all')
const timeFilterOptions = [
  { label: '全部时间', value: 'all' },
  { label: '最近24小时', value: '24h' },
  { label: '最近7天', value: '7d' },
  { label: '最近30天', value: '30d' }
]

// 修改当前播放状态的跟踪方式
const currentPlayingId = ref(null)

function formatPlayTime(timestamp) {
  const date = new Date(timestamp)
  const now = new Date()
  const diff = now - date

  if (diff < 60000) return '刚刚'
  if (diff < 3600000) return `${Math.floor(diff / 60000)}分钟前`
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}小时前`
  if (diff < 604800000) return `${Math.floor(diff / 86400000)}天前`
  
  return date.toLocaleDateString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// 修改播放音乐函数
function playMusic(song) {
  const musicInstanceId = `${song.dj_table_id}_${song.song_name}`
  
  // 确保使用最新的封面
  if (song.song_id) {
    fetch(`https://api.qijieya.cn/meting/?type=song&id=${song.song_id}`)
      .then(response => response.json())
      .then(songData => {
        if (songData && songData.pic) {
          // 使用获取到的新封面
          playSongWithCover(song, musicInstanceId, songData.pic);
        } else {
          // 使用原有封面
          playSongWithCover(song, musicInstanceId, song.song_avatar);
        }
      })
      .catch(error => {
        console.error('获取歌曲信息失败:', error);
        playSongWithCover(song, musicInstanceId, song.song_avatar);
      });
  } else {
    // 如果没有歌曲ID，使用原有封面
    playSongWithCover(song, musicInstanceId, song.song_avatar);
  }
}

// 使用指定封面播放歌曲
function playSongWithCover(song, musicInstanceId, coverUrl) {
  // If the song URL doesn't already use the new API format, update it
  const songUrl = song.song_url && song.song_url.includes('api.qijieya.cn') 
    ? song.song_url 
    : (song.song_id ? `https://api.qijieya.cn/meting/?type=url&id=${song.song_id}` : song.song_url);
  
  fetch(`https://${GetParentResourceName()}/playMusic`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
      url: songUrl,
      name: song.song_name,
      djTableId: song.dj_table_id,
      artist: song.song_artist,
      album: song.song_album,
      duration: song.song_duration,
      avatar: coverUrl
    })
  }).then(() => {
    // 更新播放状态
    currentPlayingId.value = musicInstanceId
    // 更新底部播放器信息
    currentMusic.value = {
      name: song.song_name,
      artist: song.song_artist,
      album: song.song_album,
      avatar: coverUrl,
      url: songUrl,
      duration: song.song_duration,
      djTableId: song.dj_table_id,
      isPlaying: true,
      musicInstanceId: musicInstanceId,
      id: song.song_id
    }
  })
}

function fetchRecentPlays() {
  if (!currentMusic.value.djTableId) {
    console.log("No DJ table ID available")
    return
  }
  
  console.log("Fetching recent plays for DJ table:", currentMusic.value.djTableId)
  
  fetch(`https://${GetParentResourceName()}/getRecentPlays`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
      djTableId: currentMusic.value.djTableId,
      page: page.value,
      pageSize: pageSize.value,
      timeFilter: timeFilter.value
    })
  })
}

function handlePageChange(currentPage) {
  page.value = currentPage
  fetchRecentPlays()
}

function handlePageSizeChange(size) {
  pageSize.value = size
  page.value = 1
  fetchRecentPlays()
}

// 添加分页事件监听
watch([page, pageSize], () => {
  fetchRecentPlays()
})

// 修改消息监听器
window.addEventListener('message', function(event) {
  if (event.data.action === 'updateRecentPlays') {
    console.log("Received recent plays update:", event.data.data)
    recentPlays.value = event.data.data.items || []
    totalItems.value = event.data.data.total || 0
    
    // 确保数据更新后重新渲染
    nextTick(() => {
      console.log("Recent plays updated:", recentPlays.value)
    })
  } else if (event.data.action === 'musicStarted') {
    // 更新播放状态
    console.log("Music started:", event.data.musicInfo)
    currentPlayingId.value = event.data.musicInfo.id
  } else if (event.data.action === 'trackEnded') {
    // 清除播放状态
    currentPlayingId.value = null
    currentMusic.value.isPlaying = false
  }
})

// 监听时间筛选变化
watch(timeFilter, () => {
  page.value = 1
  fetchRecentPlays()
})

// 监听DJ台变化
watch(() => currentMusic.value.djTableId, (newId, oldId) => {
  console.log("DJ table changed:", newId)
  if (newId && newId !== oldId) {
    page.value = 1
    fetchRecentPlays()
  }
})

// 添加自动刷新逻辑
let refreshInterval
onMounted(() => {
  if (currentMusic.value.djTableId) {
    fetchRecentPlays()
    // 每15秒自动刷新一次
    refreshInterval = setInterval(fetchRecentPlays, 15000)
  }
})

onUnmounted(() => {
  if (refreshInterval) {
    clearInterval(refreshInterval)
  }
})
</script>

<style scoped>
/* 主容器 */
.recent-plays {
  /* height: 100%;
  display: flex; */
  flex-direction: column;
  padding: 20px;
  /* box-sizing: border-box; */
  position: relative;
  /* background: #1a1a1a; */
}

/* 头部区域 */
.header {
  flex: none; /* 防止头部被压缩 */
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 20px;
}

.title-section h2 {
  margin: 0;
  font-size: 28px;
  font-weight: 600;
  margin-bottom: 8px;
}

.subtitle {
  color: #999;
  font-size: 14px;
}

/* 列表区域 */
.music-list {
  flex: 1;
  margin-top: 20px;
  max-width: 100%;
  overflow-y: auto;
  margin-bottom: 20px;
  padding-right: 4px;
}

/* 自定义滚动条样式 */
.music-list::-webkit-scrollbar {
  width: 4px;
}

.music-list::-webkit-scrollbar-track {
  background: transparent;
}

.music-list::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 2px;
}

.music-list::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.2);
}

/* 隐藏默认滚动条 */
.music-list {
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE and Edge */
}

.music-list::-webkit-scrollbar {
  display: none; /* Chrome, Safari and Opera */
}

.music-item {
  display: flex;
  align-items: center;
  padding: 12px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  margin-bottom: 12px;
  transition: all 0.3s ease;
  gap: 15px;
  max-width: 100%;
  background: rgba(0, 0, 0, 0.2);
}

.music-item:hover {
  background: rgba(255, 255, 255, 0.05);
  transform: translateX(5px);
}

.item-index {
  flex: 0 0 30px;
  text-align: center;
  color: #888;
}

.music-cover {
  flex: 0 0 40px;
  width: 40px;
  height: 40px;
  position: relative;
  cursor: pointer;
  border-radius: 4px;
  overflow: hidden;
}

.music-info {
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  margin-right: 15px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.song-title {
  font-size: 14px;
  color: #fff;
  margin-bottom: 4px;
  width: 100%;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.song-details {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: #888;
  width: 100%;
}

.artist, .album {
  flex: 0 1 auto;
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.play-info {
  flex: 0 0 80px;
  text-align: right;
  margin-right: 10px;
}

.play-time {
  font-size: 12px;
  color: #888;
  margin-bottom: 4px;
}

.duration {
  font-size: 12px;
  color: #666;
}

.actions {
  flex: 0 0 auto;
  display: flex;
  gap: 8px;
}

.actions .n-button {
  background: rgba(255, 255, 255, 0.1);
}

.actions .n-button:hover {
  background: rgba(255, 255, 255, 0.2);
}

.actions .n-button.playing {
  color: #1dd1a1;
}

/* 分页器容器样式调整 */
.pagination-wrapper {
  position: relative;
  margin-bottom: 80px;
  background: rgba(18, 18, 18, 0.95);
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  padding: 6px 0;
}

.pagination-content {
  width: 100%;
  max-width: 600px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.page-info {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
  display: flex;
  align-items: center;
  gap: 4px;
  min-width: 50px;
  white-space: nowrap;
}

.page-controls {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: nowrap;
}

.current-page {
  font-size: 13px;
  color: #fff;
  min-width: 20px;
  text-align: center;
}

:deep(.n-button) {
  width: 24px;
  height: 24px;
  min-width: 24px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.7);
  transition: all 0.2s ease;
  background: rgba(255, 255, 255, 0.08) !important;
  border-radius: 4px;
}

:deep(.n-button:not(:disabled):hover) {
  color: #fff;
  background: rgba(255, 255, 255, 0.15) !important;
}

:deep(.n-button:disabled) {
  opacity: 0.3;
  cursor: not-allowed;
}

/* 移动设备适配 */
@media screen and (max-width: 480px) {
  .pagination-content {
    padding: 4px;
    gap: 6px;
  }
  
  .page-info {
    font-size: 11px;
    min-width: 45px;
  }
  
  :deep(.n-button) {
    width: 22px;
    height: 22px;
    min-width: 22px;
  }
  
  .current-page {
    min-width: 18px;
    font-size: 12px;
  }
}

/* 响应式调整 */
@media screen and (max-height: 700px) {
  .recent-plays {
    padding-bottom: 100px;
  }
  
  .pagination-wrapper {
    bottom: 70px;
  }
  
  .music-list {
    margin-bottom: 50px;
  }
}

.text-ellipsis {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
