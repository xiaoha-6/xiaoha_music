<template>
    <div class="discover-container">
        <!-- 轮播图部分 -->
        <div class="banner-section">
            <n-carousel autoplay show-arrow>
                <img class="carousel-img" src="https://pic1.imgdb.cn/item/67ba76f3d0e0a243d4025a27.png" />
                <img class="carousel-img" src="https://pic1.imgdb.cn/item/67ba778cd0e0a243d4025a3f.png" />
                <img class="carousel-img" src="https://pic1.imgdb.cn/item/67ba77efd0e0a243d4025a8c.png" />
            </n-carousel>
        </div>

        <!-- 推荐歌单部分 -->
        <div class="playlist-section">
            <div class="section-header">
                <h2>推荐歌单</h2>
                <n-button text type="primary">
                    更多
                    <template #icon>
                        <n-icon><chevron-forward /></n-icon>
                    </template>
                </n-button>
            </div>
            <n-scrollbar x-scrollable>
                <div class="playlist-grid">
                    <n-button
                        v-for="playlist in playlists"
                        :key="playlist.id"
                        class="playlist-card"
                        text
                        @click="handlePlaylistClick(playlist)"
                    >
                        <img :src="playlist.cover" class="playlist-cover" :alt="playlist.name">
                        <div class="playlist-name">{{ playlist.name }}</div>
                    </n-button>
                </div>
            </n-scrollbar>
        </div>

        <!-- 每日推荐部分 -->
        <div class="recommended-songs-section">
            <div class="section-header">
                <h2>每日推荐</h2>
            </div>
            <div class="table-container">
                <n-scrollbar style="max-height: 100%;">
                    <div class="songs-list">
                        <div 
                            v-for="(song, index) in recommendedSongs" 
                            :key="song.id + index"
                            class="song-item"
                            :class="{ 'is-even': index % 2 === 0 }"
                            @click="handleSongClick(song)"
                        >
                            <div class="song-index">{{ index + 1 }}</div>
                            <div class="song-cover-wrapper">
                                <img :src="song.cover" class="song-cover" :alt="song.name">
                                <div class="play-icon">
                                    <n-icon size="16">
                                        <play-circle-outline />
                                    </n-icon>
                                </div>
                            </div>
                            <div class="song-info">
                                <span class="song-name">{{ song.name }}</span>
                                <span class="artist">{{ song.artist }}</span>
                            </div>
                            <div class="song-duration">{{ song.duration }}</div>
                        </div>
                    </div>
                </n-scrollbar>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { NCarousel, NButton, NIcon, NImage, NScrollbar } from 'naive-ui'
import { ChevronForward as chevronForward, PlayCircleOutline } from '@vicons/ionicons5'

const router = useRouter()

const playlists = ref([
    {
        id: '2619366284',
        cover: 'https://pic1.imgdb.cn/item/67ba76f3d0e0a243d4025a27.png',
        name: '私人雷达 | 为你推荐的每日好歌'
    },
    {
        id: '3778678',
        cover: 'https://pic1.imgdb.cn/item/67ba778cd0e0a243d4025a3f.png',
        name: '热歌榜 | 最新流行音乐'
    },
    {
        id: '3779629',
        cover: 'https://pic1.imgdb.cn/item/67ba77efd0e0a243d4025a8c.png',
        name: '新歌榜 | 新歌一网打尽'
    },
    {
        id: '5059642708',
        cover: 'https://pic1.imgdb.cn/item/67ba80ced0e0a243d4025afc.png',
        name: '怀旧经典 | 永恒的音乐记忆'
    },
    {
        id: '2809513713',
        cover: 'https://pic1.imgdb.cn/item/67ba80f2d0e0a243d4025b00.png',
        name: '欧美精选 | 精选欧美热门歌曲'
    }
])

const recommendedSongs = ref([])

// 获取推荐歌曲
const fetchRecommendedSongs = async () => {
  try {
    // 使用ID 3778678 (热歌榜) 作为推荐歌曲来源
    const response = await fetch('https://api.qijieya.cn/meting/?type=playlist&id=3778678');
    const data = await response.json();
    
    if (data && Array.isArray(data)) {
      // 只取前12首歌
      const songs = data.slice(0, 12).map(song => ({
        id: song.id,
        cover: song.pic,
        name: song.title,
        artist: song.author,
        duration: formatDuration(song.time || 0),
        url: song.url,
        lrc: song.lrc
      }));
      
      recommendedSongs.value = songs;
    }
  } catch (error) {
    console.error('获取推荐歌曲失败:', error);
    // 保留默认数据作为备用
  }
}

// 格式化时长
const formatDuration = (seconds) => {
  const minutes = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

const handlePlaylistClick = (playlist) => {
    router.push({
        name: 'PlaylistDetail',
        params: { id: playlist.id }
    })
}

const handleSongClick = (song) => {
    // 直接播放歌曲并跳转到详情页
    const djTableId = 'discover_player';
    
    // 确保使用最新的封面
    fetch(`https://api.qijieya.cn/meting/?type=song&id=${song.id}`)
      .then(response => response.json())
      .then(songData => {
        if (songData && songData.pic) {
          // 使用获取到的新封面
          playSongWithCover(song, djTableId, songData.pic);
        } else {
          // 使用原有封面
          playSongWithCover(song, djTableId, song.cover);
        }
      })
      .catch(error => {
        console.error('获取歌曲信息失败:', error);
        playSongWithCover(song, djTableId, song.cover);
      });
}

// 使用指定封面播放歌曲
const playSongWithCover = (song, djTableId, coverUrl) => {
    // 播放音乐
    fetch(`https://${GetParentResourceName()}/playMusic`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            url: song.url || `https://api.qijieya.cn/meting/?type=url&id=${song.id}`,
            name: song.name,
            artist: song.artist,
            album: '',
            avatar: coverUrl,
            djTableId: djTableId,
            volume: 100,
            duration: durationToSeconds(song.duration)
        })
    }).then(response => {
        if (!response.ok) {
            console.error('Failed to play music:', response.statusText);
        } else {
            // 跳转到歌曲详情页
            router.push(`/song/${song.id}`);
}
    }).catch(error => {
        console.error('Error playing music:', error);
    });
}

// 将时间格式转换为秒数
const durationToSeconds = (duration) => {
    const [minutes, seconds] = duration.split(':').map(Number);
    return minutes * 60 + seconds;
}

// 组件挂载时获取推荐歌曲
onMounted(() => {
    fetchRecommendedSongs();
})
</script>

<style scoped>
.discover-container {
    height: 100vh;
    padding: 12px 20px 80px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    overflow: hidden;
    box-sizing: border-box;
}

.banner-section {
    flex-shrink: 0;
    height: 100px;
    border-radius: 8px;
    overflow: hidden;
    margin-bottom: 4px;
}

.playlist-section {
    flex-shrink: 0;
    margin-bottom: 4px;
    overflow: hidden;
}

.section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
    padding: 0 4px;
}

.section-header h2 {
    font-size: 20px;
    color: #fff;
    margin: 0;
}

/* 推荐歌单样式 */
.playlist-grid {
    display: flex;
    gap: 12px;
    padding: 4px;
    min-width: min-content;
}

.playlist-card {
    flex: 0 0 160px;
    width: 160px;
    padding: 0;
    background: transparent;
    border: none;
    transition: transform 0.2s;
}

.playlist-card:hover {
    transform: scale(1.02);
}

.playlist-card:hover .playlist-name {
    color: var(--primary-color);
}

.playlist-cover {
    width: 160px;
    height: 160px;
    border-radius: 8px;
    margin-bottom: 8px;
    object-fit: cover;
}

.playlist-name {
    font-size: 14px;
    color: #fff;
    margin: 4px 0;
    line-height: 1.3;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    height: 36px;
    text-align: left;
    transition: color 0.2s;
}

/* 每日推荐部分 */
.recommended-songs-section {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow: hidden;
}

.table-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    border-radius: 8px;
    background: rgba(28, 28, 28, 0.8);
    backdrop-filter: blur(10px);
    overflow: hidden;
}

.songs-list {
    padding: 8px;
}

.song-item {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
    min-height: 56px;
    box-sizing: border-box;
    margin-bottom: 2px;
}

.song-item:hover {
    background: rgba(255, 255, 255, 0.1);
}

.song-item.is-even {
    background: rgba(255, 255, 255, 0.02);
}

.song-item:hover .play-icon {
    opacity: 1;
}

.song-index {
    width: 30px;
    color: #999;
    font-size: 14px;
    text-align: center;
}

.song-cover-wrapper {
    width: 40px;
    height: 40px;
    position: relative;
    margin-right: 12px;
    border-radius: 4px;
    overflow: hidden;
}

.song-cover {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.play-icon {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.5);
    opacity: 0;
    transition: opacity 0.2s;
    color: #fff;
}

.song-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
}

.song-name {
    font-size: 14px;
    color: #fff;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.artist {
    font-size: 12px;
    color: #999;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.song-duration {
    width: 80px;
    text-align: right;
    color: #999;
    font-size: 12px;
    padding-right: 12px;
}

/* 滚动条样式 */
:deep(.n-scrollbar) {
    height: 100%;
}

:deep(.n-scrollbar-container) {
    height: 100%;
}

:deep(.n-scrollbar-content) {
    padding-right: 12px;
}

:deep(.n-scrollbar-rail.n-scrollbar-rail--vertical) {
    right: 4px !important;
    top: 4px !important;
    bottom: 4px !important;
    width: 6px !important;
    background-color: rgba(255, 255, 255, 0.1) !important;
}

:deep(.n-scrollbar-rail__scrollbar) {
    background-color: rgba(255, 255, 255, 0.3) !important;
}

:deep(.n-scrollbar-rail__scrollbar:hover) {
    background-color: rgba(255, 255, 255, 0.5) !important;
}
</style>
