<template>
  <n-card :bordered="false" v-if="showPage">
    <n-grid :cols="10" style="height: 50vh;">
      <n-gi :span="2" class="nav-bar">
        <n-space vertical size="large">
          <n-space v-for="item in menuList" :key="item.name">
            <n-avatar :src="item.avatar" v-if="item.avatar" />
            <div class="title" v-if="item.isTitle">{{ item.name }}</div>
            <n-space v-else>
              <n-icon size="20" color="#8f8f8f" :component="item.icon" />
              <div class="nav-item" @click="router.push(item.path)">{{ item.name }}</div>
            </n-space>
          </n-space>
        </n-space>
      </n-gi>
      <n-gi :span="8">
        <router-view />
      </n-gi>
    </n-grid>
    <n-flex justify="space-between" style="border-top: 1px solid white;padding: 1vh;">
      <n-space style="width: 15vw;">
        <div :class="['player-avatar', { 'rotating': true, 'playing': isPlaying }]" @click="goToSongDetail">
          <n-avatar :size="45" round :src="currentMusic.avatar" id="avatar" />
        </div>
        <div>
          <div style="font-weight: bold;">{{ currentMusic.name }}《{{ currentMusic.album }}》</div>
          <div>{{ currentMusic.singer }}</div>
        </div>
      </n-space>
      <n-space vertical style="width: 30vw;" size="small">
        <n-space justify="center">
          <n-icon size="25" color="#8f8f8f" :component="PlaySkipBackSharp" style="cursor: pointer;" @click="playPrevious" />
          <div @click="togglePlay" style="cursor: pointer;">
            <n-icon size="25" color="silver" :component="PlayCircleSharp" v-if="!isPlaying" />
            <n-icon size="25" color="silver" :component="PauseCircleSharp" v-if="isPlaying" />
          </div>
          <n-icon size="25" color="#8f8f8f" :component="PlaySkipForwardSharp" style="cursor: pointer;" @click="playNext" />
        </n-space>
        <div class="progress-container">
          <span class="time-text">{{ formatTime(currentTime) }}</span>
          <n-slider
            v-model:value="currentTime"
            :step="1"
            :min="0"
            :max="duration"
            style="width: 20vw;"
            @update:value="handleProgressChange"
          />
          <span class="time-text">{{ formatTime(duration) }}</span>
        </div>
      </n-space>
      <n-space style="width: 7vw;margin-top: 1.5vh;" size="small">
        <n-icon 
          size="25" 
          :color="volume > 0 ? '#8f8f8f' : '#FF3A3A'" 
          :component="getVolumeIcon()" 
          style="cursor: pointer;"
          @click="toggleMute"
        />
        <n-slider 
          v-model:value="volume" 
          :step="1" 
          :min="0"
          :max="100"
          style="width: 4.5vw;margin-top: 0.3vh;"
          @update:value="handleVolumeChange"
        />
      </n-space>
    </n-flex>
  </n-card>
</template>

<script setup>
import { Heart, MusicalNotes, Download, ReloadCircleSharp, PlaySkipBackSharp, PlaySkipForwardSharp, PauseCircleSharp, PlayCircleSharp, VolumeHigh, VolumeMedium, VolumeLow, VolumeOff } from '@vicons/ionicons5'
import router from './router'
import { ref, onMounted, onUnmounted, watch, computed } from 'vue'
import { currentMusic, isPlaying, isPaused, updatePlayingState } from './store/music'

const showPage = ref(true)// 这个是UI隐藏开关
const menuList = ref([
  {
    name: '哈抑云',
    avatar: 'https://gimg2.baidu.com/image_search/src=http%3A%2F%2Fsafe-img.xhscdn.com%2Fbw1%2Fb1e35348-43df-4b36-9de8-6d8492c65e2f%3FimageView2%2F2%2Fw%2F1080%2Fformat%2Fjpg&refer=http%3A%2F%2Fsafe-img.xhscdn.com&app=2002&size=f9999,10000&q=a80&n=0&g=0n&fmt=auto?sec=1742712598&t=acbab8190ee8eed0fc5891429fbf27cc',
    isTitle: true
  },
  {
    name: '推荐',
    icon: Heart,
    path: '/'
  },
  {
    name: '发现音乐',
    icon: MusicalNotes,
    path: '/find'
  },
  {
    name: '我的音乐',
    isTitle: true
  },
  {
    name: '本地与下载',
    icon: Download,
    path: '/download'
  },
  {
    name: '最近播放',
    icon: ReloadCircleSharp,
    path: '/recent'
  }
])
const volume = ref(100)
const isMuted = ref(false)
const previousVolume = ref(100)
const currentTime = ref(0)
const duration = ref(0)
const progressUpdateInterval = ref(null)

function togglePlay() {
  if (!currentMusic.value.name || !currentMusic.value.djTableId) {
    console.error('No music is currently selected');
    return;
  }

  const musicInstanceId = currentMusic.value.djTableId + "_" + currentMusic.value.name;
  const action = isPlaying.value ? 'zanting' : 'bofang';
  
  console.log(`Sending ${action} request for music instance: ${musicInstanceId}`);
  
  fetch(`https://${GetParentResourceName()}/${action}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
      name: musicInstanceId
    })
  }).then(response => {
    if (!response.ok) {
      console.error(`Failed to ${action} music:`, response.statusText);
    } else {
      updatePlayingState(isPlaying.value ? 'paused' : 'playing')
    }
  }).catch(error => {
    console.error(`Error during ${action} request:`, error);
  });
}

function playPrevious() {
  fetch(`https://${GetParentResourceName()}/playPrevious`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
      currentId: currentMusic.value.id,
      useApiFormat: true // 指示后端使用新的API格式
    })
  });
}

function playNext() {
  fetch(`https://${GetParentResourceName()}/playNext`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
      currentId: currentMusic.value.id,
      useApiFormat: true // 指示后端使用新的API格式
    })
  });
}

function handleVolumeChange(newVolume) {
  if (!currentMusic.value.name || !currentMusic.value.djTableId) {
    console.error('No music is currently selected');
    return;
  }
  
  const musicInstanceId = `${currentMusic.value.djTableId}_${currentMusic.value.name}`;
  
  // 清除之前的延时
  if (progressUpdateInterval.value) {
    clearInterval(progressUpdateInterval.value);
  }

  // 使用延时来减少请求频率
  progressUpdateInterval.value = setTimeout(() => {
    console.log('Setting volume:', {
      volume: newVolume,
      musicInstanceId: musicInstanceId,
      currentMusic: currentMusic.value,
      djTableId: currentMusic.value.djTableId
    });
    
    fetch(`https://${GetParentResourceName()}/setVolume`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify({
        name: musicInstanceId,
        volume: newVolume / 100,
        djTableId: currentMusic.value.djTableId
      })
    }).then(response => {
      if (!response.ok) {
        console.error('Failed to set volume:', response.statusText);
        volume.value = previousVolume.value;
      } else {
        previousVolume.value = newVolume;
      }
    }).catch(error => {
      console.error('Error setting volume:', error);
      volume.value = previousVolume.value;
    });
  }, 100); // 100ms 延时
}

function toggleMute() {
  if (!currentMusic.value.name || !currentMusic.value.djTableId) {
    console.error('No music is currently selected');
    return;
  }
  
  if (isMuted.value) {
    // 取消静音
    volume.value = previousVolume.value;
    isMuted.value = false;
  } else {
    // 静音
    previousVolume.value = volume.value;
    volume.value = 0;
    isMuted.value = true;
  }
  
  handleVolumeChange(volume.value);
}

// 获取音量图标函数
function getVolumeIcon() {
  const currentVolume = volume.value;
  if (currentVolume === 0) return VolumeOff;
  if (currentVolume < 30) return VolumeLow;
  if (currentVolume < 70) return VolumeMedium;
  return VolumeHigh;
}

// 格式化时间的函数
function formatTime(seconds) {
  const mins = Math.floor(seconds / 60)
  const secs = Math.floor(seconds % 60)
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

// 处理进度条变化
function handleProgressChange(newTime) {
  if (!currentMusic.value.name || !currentMusic.value.djTableId) return;
  
  const musicInstanceId = `${currentMusic.value.djTableId}_${currentMusic.value.name}`;
  
  fetch(`https://${GetParentResourceName()}/setMusicTime`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify({
      name: musicInstanceId,
      time: newTime
    })
  }).catch(error => {
    console.error('Error setting music time:', error);
  });
}

// 开始更新进度
function startProgressUpdate() {
  if (progressUpdateInterval.value) {
    clearInterval(progressUpdateInterval.value);
  }

  progressUpdateInterval.value = setInterval(() => {
    if (!currentMusic.value?.name || !currentMusic.value?.djTableId) return;
    
    const musicInstanceId = `${currentMusic.value.djTableId}_${currentMusic.value.name}`;
    
    fetch(`https://${GetParentResourceName()}/getCurrentTime`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify({
        name: musicInstanceId
      })
    })
    .then(response => response.json())
    .then(data => {
      currentTime.value = data.currentTime;
      duration.value = data.duration;
    })
    .catch(error => {
      console.error('Error getting current time:', error);
    });
  }, 1000);
}

// 停止更新进度
function stopProgressUpdate() {
  if (progressUpdateInterval.value) {
    clearInterval(progressUpdateInterval.value);
    progressUpdateInterval.value = null;
  }
}

// 监听当前音乐变化
watch(() => currentMusic.value, (newMusic) => {
  if (newMusic?.name && newMusic?.djTableId) {
    startProgressUpdate();
  } else {
    stopProgressUpdate();
  }
}, { immediate: true });

// 组件挂载时启动进度更新
onMounted(() => {
  if (currentMusic.value?.name && currentMusic.value?.djTableId) {
    startProgressUpdate();
  }
});

// 组件卸载时清理定时器
onUnmounted(() => {
  stopProgressUpdate();
});

// 监听音乐播放状态变化
watch(isPlaying, (newValue) => {
  if (newValue) {
    startProgressUpdate();
  } else if (progressUpdateInterval.value) {
    clearInterval(progressUpdateInterval.value);
  }
});

// 跳转到歌曲详情页
function goToSongDetail() {
  if (currentMusic.value.id) {
    router.push(`/song/${currentMusic.value.id}`)
  }
}

window.addEventListener('message', function (event) {
  switch (event.data.action) {
    case 'openDJTable':
      showPage.value = true;
      currentMusic.value = {
        ...currentMusic.value,
        djTableId: event.data.djTableId
      };
      console.log('DJ Table opened with ID:', event.data.djTableId);
      break;
    case 'musicStarted':
      isPlaying.value = true;
      const musicInfo = event.data.musicInfo;
      currentMusic.value = {
        ...currentMusic.value,
        name: musicInfo.name || '未知歌曲',
        singer: musicInfo.artist || '未知歌手',
        album: musicInfo.album || '',
        duration: musicInfo.duration || '',
        djTableId: musicInfo.djTableId,
        avatar: musicInfo.avatar || currentMusic.value.avatar
      };
      duration.value = parseFloat(musicInfo.duration) || 0;
      startProgressUpdate();
      console.log('Music started:', currentMusic.value);
      break;
    case 'musicPaused':
      isPlaying.value = false; 
      console.log('Music paused');
      break;
    case 'musicResumed':
      isPlaying.value = true;
      console.log('Music resumed');
      break;
    case 'timeUpdate':
      currentTime.value = event.data.currentTime;
      duration.value = event.data.duration;
      break;
    case 'trackEnded':
      isPlaying.value = false;
      currentTime.value = 0;
      console.log('Track ended');
      break;
    case 'volumeUpdated':
      if (event.data.name === `${currentMusic.value.djTableId}_${currentMusic.value.name}`) {
        volume.value = event.data.volume;
        console.log('Volume updated:', {
          requestedVolume: event.data.volume,
          name: event.data.name,
          currentMusic: currentMusic.value
        });
      }
      break;
  }
});

document.addEventListener('keydown', function (event) {
  if (event.key === 'Escape') {
    fetch(`https://${GetParentResourceName()}/closeNui`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
    });
    showPage.value = false
  }
});
</script>

<style scoped>
.n-card {
  width: 60vw;
  height: 62vh;
  border-radius: 2rem;
  background-color: #2D2D2D;
  margin: 10vw auto;
  color: white;
  padding: 0.5vh;
  border: 1vh solid black;
  box-sizing: border-box;
}

.n-grid {
  height: 46vh;
  box-sizing: border-box;
  overflow: hidden;
}

.nav-bar {
  border-right: 1px solid white;
  user-select: none;
}

.title {
  font-weight: bold;
}

.nav-item {
  cursor: pointer;
  line-height: 2.5vh;
}

.progress-container {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
}

.time-text {
  font-size: 12px;
  color: #8f8f8f;
  min-width: 40px;
  text-align: center;
}

/* 播放器封面旋转动画 */
@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.player-avatar {
  width: 45px;
  height: 45px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  border: 2px solid rgba(255, 255, 255, 0.1);
  box-sizing: border-box;
  cursor: pointer;
}

.player-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* 添加旋转动画类 */
.rotating {
  animation: rotate 20s linear infinite;
  animation-play-state: paused;
}

.rotating.playing {
  animation-play-state: running;
}
</style>