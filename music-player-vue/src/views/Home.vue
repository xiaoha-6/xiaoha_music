<template>
  <n-config-provider :theme-overrides="themeOverrides">
    <div style="position:relative">
      <n-icon size="20" color="#8f8f8f" :component="Search" style="position:absolute; left:2vw; top:0.6vh;" />
      <input type="text" v-model="searchMusic" @keyup.enter="searchMethod" placeholder="搜索歌曲" class="search-input"
        style="padding-left:3ch">
    </div>
    <div style="height: 40vh;overflow-y: auto;">
      <table style="margin: 1vw;">
        <thead>
          <tr>
            <th style="width: 2vw;text-align: center;">#</th>
            <th style="width: 20vw;text-align: start;">歌曲</th>
            <th style="width: 5vw; text-align: center;">歌手</th>
            <th style="width: 10vw; text-align: center;">专辑</th>
            <th style="width: 3vw; text-align: center;">时长</th>
          </tr>
        </thead>
        <tbody style="height: 35vh;overflow-y: auto;">
          <tr v-for="(item, index) in paginatedList" :key="index" style="height: 5vh;">
            <td v-if="currentMusic.id === item.id" style="text-align: center;">
              <n-icon size="20" color="red" :component="VolumeMedium" />
            </td>
            <td v-else style="text-align: center;">{{ (currentPage - 1) * pageSize + index + 1 }}</td>
            <td style="cursor: pointer;" @click="playMusic(item)">
              <n-space>
                <n-avatar size="small" :src="item.avatar" />
                <div>{{ item.name }}</div>
              </n-space>
            </td>
            <td style="text-align: center;">{{ item.singer }}</td>
            <td style="text-align: center;">{{ item.album }}</td>
            <td style="text-align: center;">{{ item.duration }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <div class="pagination-wrapper">
      <n-space align="center" :size="4">
        <n-button 
          quaternary 
          circle 
          size="small"
          :disabled="currentPage === 1"
          @click="currentPage--"
        >
          <template #icon>
            <n-icon><chevron-back /></n-icon>
          </template>
        </n-button>
        <span class="page-text">{{ currentPage }}/{{ totalPages }}</span>
        <n-button 
          quaternary 
          circle 
          size="small"
          :disabled="currentPage === totalPages"
          @click="currentPage++"
        >
          <template #icon>
            <n-icon><chevron-forward /></n-icon>
          </template>
        </n-button>
      </n-space>
    </div>
  </n-config-provider>
</template>

<script setup>
import { Search, VolumeMedium, ChevronBack as chevronBack, ChevronForward as chevronForward } from '@vicons/ionicons5'
import { ref, computed } from 'vue'
import { currentMusic } from '../store/music'
import { NConfigProvider, NButton, NSpace, NIcon, NAvatar } from 'naive-ui'

const themeOverrides = {
  Pagination: {
    itemTextColor: '#8f8f8f',
    itemTextColorHover: '#fff',
    itemTextColorPressed: '#fff',
    itemTextColorActive: '#fff',
    itemColor: 'transparent',
    itemColorHover: '#FF3A3A20',
    itemColorPressed: '#FF3A3A30',
    itemColorActive: '#FF3A3A',
    itemBorderColor: '#404040',
    itemBorderRadius: '4px',
    buttonColor: 'transparent',
    buttonColorHover: '#FF3A3A20',
    buttonColorPressed: '#FF3A3A30',
    jumpTextColor: '#8f8f8f',
    jumpTextColorHover: '#fff',
    jumpTextColorPressed: '#fff'
  },
  Button: {
    textColorQuaternary: '#8f8f8f',
    textColorQuaternaryHover: '#fff',
    textColorQuaternaryPressed: '#fff',
    colorQuaternaryHover: '#FF3A3A20',
    colorQuaternaryPressed: '#FF3A3A40',
  }
}

const musicList = ref([
  {
    id: 1303464858,
    avatar: 'https://img2.baidu.com/it/u=3029837478,1144772205&fm=253&fmt=auto&app=120&f=JPEG?w=500&h=500',
    name: '于是',
    singer: '郑润泽',
    album: '于是',
    duration: '3:52'
  },
  {
    id: 2650083076,
    avatar: 'https://q8.itc.cn/q_70/images03/20241030/7e4e379bf5b84b6c9fb4a9fec3102d5d.jpeg',
    name: '给我个理由',
    singer: 'Zkaaai',
    album: '给我个理由',
    duration: '3:40'
  },
  {
    id: 1435177840,
    avatar: 'https://pic1.imgdb.cn/item/67ba76f3d0e0a243d4025a27.png',
    name: 'Wonderful U',
    singer: 'Zkaaai',
    album: 'Wonderful U',
    duration: '4:27'
  },
  {
    id: 2608136312,
    avatar: 'https://pic1.imgdb.cn/item/67ba778cd0e0a243d4025a3f.png',
    name: '欲望都市',
    singer: '木由C',
    album: '欲望都市',
    duration: '2:41'
  },
  {
    id: 1403318151,
    avatar: 'https://pic1.imgdb.cn/item/67ba77efd0e0a243d4025a8c.png',
    name: '把回忆拼好给你',
    singer: '王贰浪',
    album: '把回忆拼好给你',
    duration: '6:21'
  },
  {
    id: 2641867659,
    avatar: 'https://pic1.imgdb.cn/item/67ba7803d0e0a243d4025a8d.png',
    name: '一点',
    singer: 'Muyoi',
    album: '一点',
    duration: '3:20'
  },
  {
    id: 1456890009,
    avatar: 'https://pic1.imgdb.cn/item/67ba7818d0e0a243d4025a8e.png',
    name: '罗生门（Follow）',
    singer: '梨冻紧',
    album: '罗生门（Follow）',
    duration: '4:03'
  },
  {
    id: 1393138949,
    avatar: 'https://pic1.imgdb.cn/item/67ba782ad0e0a243d4025a90.png',
    name: '烂尾故事',
    singer: '梨冻紧',
    album: '烂尾故事',
    duration: '3:34'
  },
  {
    id: 2611558270,
    avatar: 'https://pic1.imgdb.cn/item/67ba7847d0e0a243d4025a94.png',
    name: 'No Cap ( Phonk口水）',
    singer: 'GuTs',
    album: 'No Cap ( Phonk口水）',
    duration: '2:16'
  },
  {
    id: 1895330088,
    avatar: 'https://pic1.imgdb.cn/item/67ba785ad0e0a243d4025a97.png',
    name: '予你',
    singer: '队长',
    album: '予你',
    duration: '3:51'
  },
  {
    id: 2674443509,
    avatar: 'https://pic1.imgdb.cn/item/67ba80ced0e0a243d4025afc.png',
    name: '像晴天像雨天',
    singer: '汪苏泷',
    album: '像晴天像雨天',
    duration: '3:51'
  },
  {
    id: 2049512697,
    avatar: 'https://pic1.imgdb.cn/item/67ba80f2d0e0a243d4025b00.png',
    name: '向云端',
    singer: '海洋Bo',
    album: '向云端',
    duration: '4:11'
  },
  {
    id: 1811752787,
    avatar: 'https://pic1.imgdb.cn/item/67ba8109d0e0a243d4025b07.png',
    name: 'u got my soul',
    singer: 'bill',
    album: 'u got my soul',
    duration: '3:46'
  },
  {
    id: 2122953316,
    avatar: 'https://pic1.imgdb.cn/item/67ba8140d0e0a243d4025b0c.png',
    name: '黑白天',
    singer: '邓亦宇',
    album: '黑白天',
    duration: '3:16'
  },
  {
    id: 5257963,
    avatar: 'https://pic1.imgdb.cn/item/67ba8162d0e0a243d4025b0e.png',
    name: '最佳损友',
    singer: '张学友',
    album: '最佳损友',
    duration: '4:03'
  },
  {
    id: 1934630654,
    avatar: 'https://pic1.imgdb.cn/item/67ba8187d0e0a243d4025b13.png',
    name: '十年',
    singer: '陈奕迅',
    album: '十年',
    duration: '3:06'
  },
  {
    id: 1931647519,
    avatar: 'https://pic1.imgdb.cn/item/67ba819ed0e0a243d4025b18.png',
    name: '够钟',
    singer: '阿梨粤',
    album: '够钟',
    duration: '4:16'
  },
  {
    id: 346013,
    avatar: 'https://pic1.imgdb.cn/item/67ba81b7d0e0a243d4025b4d.png',
    name: '海阔天空',
    singer: '黄贯中',
    album: '海阔天空',
    duration: '6:06'
  },
  {
    id: 1824449700,
    avatar: 'https://pic1.imgdb.cn/item/67ba81cfd0e0a243d4025b86.png',
    name: '富士山下（国粤版）（翻自 Eason',
    singer: '浮梦',
    album: '富士山下（国粤版）（翻自 Eason',
    duration: '4:16'
  },
  {
    id: 2610953364,
    avatar: 'https://pic1.imgdb.cn/item/67ba81e2d0e0a243d4025b9f.png',
    name: '在加纳共和国离婚 (你还爱我吗)',
    singer: '橙子',
    album: '在加纳共和国离婚 (你还爱我吗)',
    duration: '4:20'
  },
  {
    id: 25657492,
    avatar: 'https://pic1.imgdb.cn/item/67ba81f4d0e0a243d4025bbd.png',
    name: 'Tik Tok (Live)',
    singer: 'Avril Lavigne',
    album: 'Tik Tok (Live)',
    duration: '4:20'
  },
  {
    id: 1886396470,
    avatar: 'https://pic1.imgdb.cn/item/67ba8206d0e0a243d4025bee.png',
    name: '勿念',
    singer: '岑宁儿',
    album: '勿念',
    duration: '3:26'
  },
  {
    id: 2645500113,
    avatar: 'https://pic1.imgdb.cn/item/67ba822dd0e0a243d4025c1d.png',
    name: '跳楼机',
    singer: 'LBI利比',
    album: '跳楼机',
    duration: '3:26'
  },
  {
    id: 2671228586,
    avatar: 'https://pic1.imgdb.cn/item/67ba8255d0e0a243d4025c1e.png',
    name: '时间变',
    singer: 'John Lee',
    album: '时间变',
    duration: '3:20'
  },
])

const searchMusic = ref('')

const currentPage = ref(1)
const pageSize = 10

const totalPages = computed(() => Math.ceil(musicList.value.length / pageSize))

const paginatedList = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  const end = start + pageSize
  return musicList.value.slice(start, end)
})

function searchMethod() {
  const name = searchMusic.value.replace(/\s+/g, '')
  
  // 根据用户要求，搜索API继续使用原来的，其他改用新API
  const apiUrl = `https://music.163.com/api/search/get?s=${encodeURIComponent(name)}&type=1&offset=0&limit=15`;
  // 也可以使用新API，但根据要求保留原API
  // const apiUrl = `https://api.qijieya.cn/meting/?server=netease&type=search&keyword=${encodeURIComponent(name)}&limit=15`;
  
  fetch(`https://${GetParentResourceName()}/fetchMusicData`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ 
      search: apiUrl,
      useNewFormat: true // 指示后端处理时添加新API格式的URL字段
    }),
  });
}
function InitData(data) {
  const musicData = typeof data === 'string' ? JSON.parse(data) : data;
  if (!musicData.result) return;
  const songs = musicData.result.songs;
  if (!Array.isArray(songs)) return;
  if (songs.length == 0) return;
  musicList.value = [];
  currentPage.value = 1; // 重置页码
  songs.forEach(a => {
    let musicInfo = {}
    musicInfo.id = a.id
    musicInfo.name = a.name
    // 歌手
    musicInfo.singer = '未知艺术家'
    if (a.artists && a.artists[0]) {
      musicInfo.singer = a.artists[0].name;
    } else if (a.ar && a.ar[0]) {
      musicInfo.singer = a.ar[0].name;
    }
    
    // 设置默认封面，稍后会被异步更新
    musicInfo.avatar = 'https://pic1.imgdb.cn/item/67ba504dd0e0a243d4025680.jpg';
    
    // 尝试从原数据中获取封面
    if (a.album && a.album.picUrl) {
      musicInfo.avatar = a.album.picUrl;
    } else if (a.al && a.al.picUrl) {
      musicInfo.avatar = a.al.picUrl;
    }
    
    // 添加到列表中，后面会异步更新封面
    musicInfo.album = a.album && a.album.name ? a.album.name : (a.al && a.al.name ? a.al.name : '新晋歌手');
    let timeNumber = Math.floor(a.duration / 1000);
    musicInfo.duration = Math.floor(timeNumber / 60) + ':' + (timeNumber % 60 < 10 ? '0' + timeNumber % 60 : timeNumber % 60);
    
    // 添加API相关字段
    musicInfo.url = `https://api.qijieya.cn/meting/?type=url&id=${a.id}`;
    musicInfo.lrc = `https://api.qijieya.cn/meting/?type=lrc&id=${a.id}`;
    
    // 将音乐信息添加到列表中
    musicList.value.push(musicInfo);
    
    // 使用新API获取歌曲封面和歌词
    Promise.all([
      fetch(`https://api.qijieya.cn/meting/?server=netease&type=song&id=${a.id}`),
      fetch(musicInfo.lrc)
    ])
      .then(([coverResponse, lrcResponse]) => {
        if (!coverResponse.ok) throw new Error('封面获取失败');
        if (!lrcResponse.ok) throw new Error('歌词获取失败');
        return Promise.all([coverResponse.json(), lrcResponse.text()]);
      })
      .then(([songData, lrcText]) => {
        // 更新封面
        if (songData && songData[0] && songData[0].pic) {
          const index = musicList.value.findIndex(item => item.id === a.id);
          if (index !== -1) {
            musicList.value[index].avatar = songData[0].pic;
            console.log(`歌曲 ${a.name} 封面已更新: ${songData[0].pic}`);
          }
        }

        // 保存歌词到内存中，但不立即存储到文件
        // 将歌词信息和内容保存到音乐对象中，以便播放时使用
        const index = musicList.value.findIndex(item => item.id === a.id);
        if (index !== -1) {
          musicList.value[index].lrcData = {
            id: a.id,
            name: a.name,
            artist: musicInfo.singer,
            album: musicInfo.album,
            duration: musicInfo.duration,
            avatar: songData && songData[0] && songData[0].pic ? songData[0].pic : musicInfo.avatar,
            lrc: lrcText,
            saveTime: new Date().toISOString()
          };
          musicList.value[index].lrcText = lrcText;
        }
      })
      .catch(error => {
        console.error(`获取歌曲 ${a.name} 信息失败:`, error);
      });
  })
}
function getSeconds(time) {
  const [minutes, seconds] = time.split(':')
  return parseInt(minutes) * 60 + parseInt(seconds)
}
//播放方法
function playMusic(item) {
  // 获取当前正在使用的 DJ Table ID
  const djTableId = currentMusic.value.djTableId || 'galaxy_club'; // 使用默认值
  
  // 尝试获取最新的歌曲信息，确保有最新的封面
  fetch(`https://api.qijieya.cn/meting/?server=netease&type=song&id=${item.id}`)
    .then(response => response.json())
    .then(songData => {
      if (songData && songData[0] && songData[0].pic) {
        // 使用新API获取的封面
        startPlayMusic(item, djTableId, songData[0].pic);
      } else {
        // 使用当前封面
        startPlayMusic(item, djTableId, item.avatar);
      }
    })
    .catch(error => {
      console.error('获取歌曲信息失败:', error);
      // 发生错误时使用当前封面
      startPlayMusic(item, djTableId, item.avatar);
    });
}

// 实际开始播放音乐的函数
function startPlayMusic(item, djTableId, coverUrl) {
  // 直接更新共享状态
  currentMusic.value = {
    ...item,
    djTableId: djTableId,
    avatar: coverUrl
  };
  
  console.log('Playing music:', {
    name: item.name,
    djTableId: djTableId,
    avatar: coverUrl
  });
  
  // 如果歌曲有歌词数据，保存到服务器
  if (item.lrcData) {
    const fileName = `${item.id}_${item.name.replace(/[^a-zA-Z0-9]/g, '')}.json`;
    fetch(`https://${GetParentResourceName()}/saveLyricsFile`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify({
        fileName: fileName,
        content: JSON.stringify(item.lrcData, null, 2)
      })
    })
    .then(response => {
      return response.json().catch(err => {
        console.warn("解析响应JSON失败，使用默认值", err);
        return { success: true };
      });
    })
    .then(result => {
      if (result && result.success) {
        console.log(`歌曲 ${item.name} 的歌词已保存`);
      }
    })
    .catch(error => {
      console.error(`保存歌词文件失败:`, error);
    });
  }

  fetch(`https://${GetParentResourceName()}/playMusic`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      url: `https://api.qijieya.cn/meting/?server=netease&type=url&id=${item.id}`,
      name: item.name,
      artist: item.singer,
      album: item.album,
      avatar: coverUrl,
      djTableId: djTableId,
      volume: 100,
      duration: getSeconds(item.duration),
      id: item.id // 添加歌曲ID，确保后端可以识别歌曲
    })
  }).then(response => {
    if (!response.ok) {
      console.error('Failed to play music:', response.statusText);
    }
  }).catch(error => {
    console.error('Error playing music:', error);
  });
}

window.addEventListener('message', function (event) {
  switch (event.data.action) {
    case 'musicData':
      InitData(event.data.data);
      break;
    default:
      break;
  }
})
</script>

<style scoped>
.search-input {
  margin-left: 1.6vw;
  width: 10vw;
  height: 1.6rem;
  border-radius: 1rem;
  background-color: #2D2D2D;
  color: white;
  caret-color: white;
  font-size: 0.8rem;
}

.search-input:focus {
  outline: none;
}

.search-input::placeholder {
  color: #8f8f8f;
}

::-webkit-scrollbar {
  width: 0.2vw;
  background-color: #2D2D2D;
}

::-webkit-scrollbar-thumb {
  background-color: #FF3A3A;
  border-radius: 1rem;
}

::-webkit-scrollbar-track {
  background-color: #404040;
}

.pagination-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  margin-top: 1vh;
}

.page-text {
  color: #8f8f8f;
  font-size: 12px;
  margin: 0 8px;
  min-width: 40px;
  text-align: center;
}

:deep(.n-button) {
  width: 24px;
  height: 24px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
}

:deep(.n-button:not(:disabled):hover) {
  color: #fff;
}

:deep(.n-button--disabled) {
  opacity: 0.5;
}
</style>
