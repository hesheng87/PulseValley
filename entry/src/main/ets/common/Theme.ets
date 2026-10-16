/**
 * 脉动光谷 - 视觉主题（对应"夜间运动"场景暗色设计）
 * 配色对齐《产品需求设计文档》16.2：脉动绿 / 光谷橙 / 智能蓝 / 深夜跑道
 */
export class Theme {
  static readonly BG_TOP: string = '#101820'
  static readonly BG_BOTTOM: string = '#17212B'
  static readonly CARD_BG: string = 'rgba(255,255,255,0.07)'
  static readonly CARD_STROKE: string = 'rgba(255,255,255,0.10)'
  static readonly TEXT_MAIN: string = '#EAEFF7'
  static readonly TEXT_SUB: string = '#8A93AD'
  /** 脉动绿 #31D07F */
  static readonly GREEN: string = '#31D07F'
  /** 智能蓝 #2F80ED */
  static readonly BLUE: string = '#2F80ED'
  /** 光谷橙 #FF8A3D */
  static readonly ORANGE: string = '#FF8A3D'
  /** 竞速红 #EF4444 */
  static readonly RED: string = '#EF4444'
  static readonly PURPLE: string = '#8B5CF6'
  /** 运动主渐变：脉动绿 -> 智能蓝 */
  static readonly GRADIENT_SPORT: string = '#31D07F'
  static readonly GRADIENT_SPORT_END: string = '#2F80ED'
  /** 挑战主渐变：光谷橙 -> 竞速红 */
  static readonly GRADIENT_CHALLENGE: string = '#FF8A3D'
  static readonly GRADIENT_CHALLENGE_END: string = '#EF4444'
  /** 成功绿 */
  static readonly SUCCESS: string = '#22C55E'
  /** 警示黄 */
  static readonly WARNING: string = '#FBBF24'
  static readonly RADIUS_CARD: number = 18
  static readonly RADIUS_BTN: number = 24
}
