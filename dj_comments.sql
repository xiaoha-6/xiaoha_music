-- --------------------------------------------------------
-- 主机:                           127.0.0.1
-- 服务器版本:                        11.5.2-MariaDB - mariadb.org binary distribution
-- 服务器操作系统:                      Win64
-- HeidiSQL 版本:                  12.6.0.6765
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- 导出 esx1.10.7 的数据库结构
CREATE DATABASE IF NOT EXISTS `esx1.10.7` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin */;
USE `esx1.10.7`;

-- 导出  表 esx1.10.7.dj_comments 结构
CREATE TABLE IF NOT EXISTS `dj_comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `song_id` text NOT NULL,
  `user_identifier` varchar(100) NOT NULL,
  `user_name` varchar(100) NOT NULL,
  `content` text NOT NULL,
  `likes` int(11) DEFAULT 0,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `song_name` varchar(100) NOT NULL,
  `song_artist` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_song_id` (`song_id`(768))
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- 正在导出表  esx1.10.7.dj_comments 的数据：~4 rows (大约)
INSERT INTO `dj_comments` (`id`, `song_id`, `user_identifier`, `user_name`, `content`, `likes`, `created_at`, `song_name`, `song_artist`) VALUES
	(1, 'https://music.163.com/song/media/outer/url?id=28875146.mp3', 'char1:c916dd2033d4a16be4662bec1fd5902a3cfdfa93', 'Xiao Haha', '海阔', 0, '2025-01-24 02:34:10', '海阔天空 (Live)', 'Beyond'),
	(2, 'https://music.163.com/song/media/outer/url?id=28875146.mp3', 'char1:c916dd2033d4a16be4662bec1fd5902a3cfdfa93', 'Xiao Haha', '小哈很喜欢你', 1, '2025-01-24 02:34:29', '海阔天空 (Live)', 'Beyond'),
	(3, 'https://music.163.com/song/media/outer/url?id=28875146.mp3', 'char1:c916dd2033d4a16be4662bec1fd5902a3cfdfa93', 'Xiao Haha', '小哈真的很喜欢你，你能跟我在一起吗？', 0, '2025-01-24 02:37:13', '海阔天空 (Live)', 'Beyond'),
	(4, 'https://music.163.com/song/media/outer/url?id=2656235467.mp3', 'char1:c916dd2033d4a16be4662bec1fd5902a3cfdfa93', 'Xiao Haha', '小哈很喜欢你', 1, '2025-01-24 03:12:43', '茶花开了', '风雪夜归人');

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
