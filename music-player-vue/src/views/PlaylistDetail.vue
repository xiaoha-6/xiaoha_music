<template>
    <div class="playlist-detail-container">
        <!-- 添加返回按钮 -->
        <div class="back-header">
            <n-button text @click="handleBack" class="back-button">
                <template #icon>
                    <n-icon size="18">
                        <arrow-back />
                    </n-icon>
                </template>
                返回
            </n-button>
        </div>

        <!-- 歌单信息头部 -->
        <div class="playlist-header">
            <div class="cover-section">
                <img :src="playlistInfo.cover" class="playlist-cover" :alt="playlistInfo.name">
            </div>
            <div class="info-section">
                <h1 class="playlist-title">{{ playlistInfo.name }}</h1>
                <p class="playlist-desc">{{ playlistInfo.description }}</p>
                <div class="action-buttons">
                    <n-button type="primary" size="small">
                        播放全部
                    </n-button>
                </div>
            </div>
        </div>

        <!-- 歌曲列表 -->
        <div class="songs-container">
            <n-scrollbar>
                <div class="songs-list">
                    <div 
                        v-for="(song, index) in songs" 
                        :key="song.id"
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
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { NButton, NScrollbar, NIcon } from 'naive-ui'
import { PlayCircleOutline, ArrowBack } from '@vicons/ionicons5'

const route = useRoute()
const router = useRouter()

// 歌单基本信息
const playlistInfo = ref({
    cover: '',
    name: '',
    description: ''
})

// 歌曲列表
const songs = ref([])

// 添加返回函数
const handleBack = () => {
    router.back()
}

// 模拟获取歌单数据
const fetchPlaylistData = async (id) => {
    try {
        // 使用新的API获取歌单数据
        const response = await fetch(`https://api.qijieya.cn/meting/?type=playlist&id=${id}`);
        const data = await response.json();
        
        if (data && Array.isArray(data)) {
            // 格式化数据
            const playlistInfo = {
                cover: data[0]?.pic || 'https://pic1.imgdb.cn/item/67ba76f3d0e0a243d4025a27.png',
                name: data[0]?.title ? `歌单 | ${data[0].title}` : '歌单',
                description: `共${data.length}首歌曲`,
                songs: []
            };
            
            // 转换歌曲数据格式
            data.forEach(song => {
                playlistInfo.songs.push({
                    id: song.id,
                    cover: song.pic,
                    name: song.title,
                    artist: song.author,
                    duration: formatDuration(song.time || 0),
                    url: song.url,
                    lrc: song.lrc
                });
            });
            
            return playlistInfo;
        }
        
        // 如果API请求失败，返回默认数据
        return fallbackPlaylistData[id] || null;
    } catch (error) {
        console.error('获取歌单数据失败:', error);
        return fallbackPlaylistData[id] || null;
    }
}

// 格式化时长
const formatDuration = (seconds) => {
    const minutes = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

// 备用数据
const fallbackPlaylistData = {
        'personal-radar': {
            cover: 'https://pic1.imgdb.cn/item/67ba76f3d0e0a243d4025a27.png',
            name: '私人雷达',
            description: '为你推荐的每日好歌',
            songs: [
                {
                    id: 1,
                    cover: 'https://pic1.imgdb.cn/item/67ba76f3d0e0a243d4025a27.png',
                    name: '习惯失恋',
                    artist: '容祖儿',
                    duration: '03:56'
                },
                {
                    id: 2,
                    cover: 'https://pic1.imgdb.cn/item/67ba778cd0e0a243d4025a3f.png',
                    name: '我看了56次日落',
                    artist: 'ET',
                    duration: '02:33'
                },
                {
                    id: 3,
                    cover: 'https://pic1.imgdb.cn/item/67ba77efd0e0a243d4025a8c.png',
                    name: '可惜没如果',
                    artist: '林俊杰',
                    duration: '04:58'
                },
                {
                    id: 4,
                    cover: 'https://pic1.imgdb.cn/item/67ba80ced0e0a243d4025afc.png',
                    name: '幸福慢慢来',
                    artist: '李荣浩',
                    duration: '02:40'
                }
            ]
        },
        // ... 其他歌单数据 ...
}

const handleSongClick = (song) => {
    // 处理歌曲点击，直接播放音乐而不是跳转到详情页
    const djTableId = 'playlist_player';
    
    // 确保有最新的封面
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
            // 可以选择跳转到歌曲详情页
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

onMounted(async () => {
    const playlistId = route.params.id
    const data = await fetchPlaylistData(playlistId)
    if (data) {
        playlistInfo.value = {
            cover: data.cover,
            name: data.name,
            description: data.description
        }
        songs.value = data.songs
    }
})
</script>

<style scoped>
.playlist-detail-container {
    height: 100vh;
    padding: 12px 20px 80px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    overflow: hidden;
    box-sizing: border-box;
}

/* 添加返回按钮样式 */
.back-header {
    margin-bottom: 16px;
}

.back-button {
    display: flex;
    align-items: center;
    color: #fff;
    font-size: 14px;
    transition: color 0.2s;
}

.back-button:hover {
    color: var(--primary-color);
}

/* 调整图标和文字的间距 */
.back-button :deep(.n-icon) {
    margin-right: 4px;
}

.playlist-header {
    display: flex;
    gap: 20px;
    padding-bottom: 20px;
}

.cover-section {
    width: 200px;
    height: 200px;
    flex-shrink: 0;
}

.playlist-cover {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 8px;
}

.info-section {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 12px;
}

.playlist-title {
    font-size: 24px;
    font-weight: bold;
    margin: 0;
    color: #fff;
}

.playlist-desc {
    font-size: 14px;
    color: #999;
    margin: 0;
}

.songs-container {
    flex: 1;
    overflow: hidden;
    background: rgba(28, 28, 28, 0.8);
    border-radius: 8px;
    backdrop-filter: blur(10px);
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
}

:deep(.n-scrollbar-rail) {
    background-color: rgba(255, 255, 255, 0.1) !important;
}

:deep(.n-scrollbar-content) {
    padding-right: 8px;
}
</style>
