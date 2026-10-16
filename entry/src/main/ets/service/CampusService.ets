/**
 * 脉动光谷 - 校园服务
 * 校园绑定（学校 + 学号实名校验，演示版为本地校验规则）
 * 校友圈：同校/跨校校友目录；校园运动榜单：本周里程榜（个人维度）
 */
import { AlumniUser, CampusInfo, LeaderEntry } from '../common/Types'
import { StoreService } from './StoreService'

export class CampusService {
  /** 支持绑定的校园列表 */
  static schools(): string[] {
    return ['光谷大学', '东湖学院', '珞珈理工大学', '汤逊湖师范大学', '关山职业技术学院']
  }

  static getInfo(): CampusInfo {
    return StoreService.getInstance().getCampusInfo()
  }

  static isBound(): boolean {
    const info: CampusInfo = CampusService.getInfo()
    return info.verified && info.school !== ''
  }

  /**
   * 绑定校园：校验规则（演示版）——学校非空 + 学号 6-12 位数字 + 姓名非空
   * 返回错误提示，绑定成功返回空字符串
   */
  static bind(school: string, studentId: string, studentName: string): string {
    if (school === '') {
      return '请选择学校'
    }
    if (studentName === '') {
      return '请输入姓名'
    }
    if (studentId.length < 6 || studentId.length > 12) {
      return '学号应为 6 - 12 位'
    }
    const info: CampusInfo = new CampusInfo()
    info.school = school
    info.studentId = studentId
    info.studentName = studentName
    info.verified = true
    info.boundTs = Date.now()
    StoreService.getInstance().saveCampusInfo(info)
    StoreService.getInstance().flush()
    return ''
  }

  static unbind(): void {
    StoreService.getInstance().saveCampusInfo(new CampusInfo())
    StoreService.getInstance().flush()
  }

  /** ---------- 校友圈 ---------- */

  /** 校友目录：我 + 种子校友（按绑定学校标注同校） */
  static listAlumni(): AlumniUser[] {
    const info: CampusInfo = CampusService.getInfo()
    const myStats = StoreService.getInstance().getUserStats()
    const me: AlumniUser = AlumniUser.of('me', info.studentName !== '' ? info.studentName : '我', '🏃',
      info.school !== '' ? info.school : '光谷大学', '我的学院',
      Math.round(myStats.totalKm * 10) / 10, true)
    const seeded: AlumniUser[] = [
      AlumniUser.of('al_1', '追风少年', '🏃', '光谷大学', '体育学院', 42.6, false),
      AlumniUser.of('al_2', '阿凯', '🏃', '光谷大学', '计算机学院', 28.4, false),
      AlumniUser.of('al_3', '小曼', '🧘', '东湖学院', '外语学院', 21.7, false),
      AlumniUser.of('al_4', '大川', '🚴', '珞珈理工大学', '机械学院', 35.2, false),
      AlumniUser.of('al_5', '露露', '🎧', '光谷大学', '新闻学院', 15.9, false),
      AlumniUser.of('al_6', '老周', '🏃', '汤逊湖师范大学', '经管学院', 32.1, false),
      AlumniUser.of('al_7', '铁牛', '💪', '光谷大学', '材料学院', 18.8, false),
      AlumniUser.of('al_8', '云朵', '🧗', '关山职业技术学院', '设计学院', 12.3, false)
    ]
    const list: AlumniUser[] = [me]
    for (let i = 0; i < seeded.length; i++) {
      list.push(seeded[i])
    }
    return list
  }

  /** 同校校友数量 */
  static sameSchoolCount(): number {
    const info: CampusInfo = CampusService.getInfo()
    if (!CampusService.isBound()) {
      return 0
    }
    const list: AlumniUser[] = CampusService.listAlumni()
    let count: number = 0
    for (let i = 0; i < list.length; i++) {
      if (list[i].school === info.school) {
        count += 1
      }
    }
    return count
  }

  /** 校园运动榜单（本周里程，含校友 + 我；绑定的学校置顶展示校名） */
  static campusBoard(): LeaderEntry[] {
    const info: CampusInfo = CampusService.getInfo()
    const list: AlumniUser[] = CampusService.listAlumni()
    const entries: LeaderEntry[] = []
    for (let i = 0; i < list.length; i++) {
      const a: AlumniUser = list[i]
      const sameSchool: boolean = CampusService.isBound() && a.school === info.school
      entries.push(LeaderEntry.of(a.name, a.avatar, a.weeklyKm,
        sameSchool ? `${a.school} · 同校` : a.school, a.isMe))
    }
    entries.sort((a: LeaderEntry, b: LeaderEntry): number => b.km - a.km)
    return entries
  }
}
