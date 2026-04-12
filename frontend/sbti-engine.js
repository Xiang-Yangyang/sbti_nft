/**
 * SBTI 人格测试算法引擎
 * 完整复刻：31道题 → 15维度打分 → 曼哈顿距离匹配 → 27种人格
 */

// ============ 15 个维度定义 ============
const DIMENSIONS = [
  { code: 'S1',  name: '自尊自信',   model: '自我模型' },
  { code: 'S2',  name: '自我清晰度', model: '自我模型' },
  { code: 'S3',  name: '核心价值',   model: '自我模型' },
  { code: 'E1',  name: '依恋安全感', model: '情感模型' },
  { code: 'E2',  name: '情感投入度', model: '情感模型' },
  { code: 'E3',  name: '边界与依赖', model: '情感模型' },
  { code: 'A1',  name: '世界观倾向', model: '态度模型' },
  { code: 'A2',  name: '规则与灵活度', model: '态度模型' },
  { code: 'A3',  name: '人生意义感', model: '态度模型' },
  { code: 'Ac1', name: '动机导向',   model: '行动驱力' },
  { code: 'Ac2', name: '决策风格',   model: '行动驱力' },
  { code: 'Ac3', name: '执行模式',   model: '行动驱力' },
  { code: 'So1', name: '社交主动性', model: '社交模型' },
  { code: 'So2', name: '人际边界感', model: '社交模型' },
  { code: 'So3', name: '表达与真实度', model: '社交模型' },
];

// ============ 31 道题目 ============
// dim: 对应维度索引 (0-14), reverse: 是否反题
const QUESTIONS = [
  // ---- 自我模型 S1 (题1-2) ----
  {
    id: 1, dim: 0, reverse: false,
    text: '我总觉得自己不够好，身边的人都比我优秀。',
    options: [
      { label: '确实', value: 1 },
      { label: '有时', value: 2 },
      { label: '不是', value: 3 },
    ]
  },
  {
    id: 2, dim: 0, reverse: false,
    text: '我觉得自己普通又不起眼，自卑又胆小，从没真正谈过恋爱，青春只剩幻想。现实里家境普通、学校一般、未来迷茫，没能力没目标，每次看到别人调侃类似人群都很难受，像只躲在暗处的老鼠，只敢偷偷仰望光亮，希望能多一点理解和包容。',
    options: [
      { label: '我哭了..', value: 1 },
      { label: '这是什么..', value: 2 },
      { label: '这不是我！', value: 3 },
    ]
  },
  // ---- 自我模型 S2 (题3-4) ----
  {
    id: 3, dim: 1, reverse: false,
    text: '我很清楚真实的自己到底是什么样子。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  {
    id: 4, dim: 1, reverse: false,
    text: '我内心有真正想要坚持和追求的东西。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  // ---- 自我模型 S3 (题5-6) ----
  {
    id: 5, dim: 2, reverse: false,
    text: '我一定要不断提升自己，变得越来越强。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  {
    id: 6, dim: 2, reverse: false,
    text: '别人怎么评价我，我根本不在乎。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  // ---- 情感模型 E1 (题7-8) ----
  {
    id: 7, dim: 3, reverse: false,
    text: '对象超过5小时没回消息，后来解释说自己拉稀，你心里会怎么想？',
    options: [
      { label: '拉稀不可能5小时，也许ta隐瞒了我。', value: 1 },
      { label: '在信任和怀疑之间摇摆。', value: 2 },
      { label: '也许今天ta真的不太舒服。', value: 3 },
    ]
  },
  {
    id: 8, dim: 3, reverse: false,
    text: '在感情里，我经常会害怕被对方抛弃。',
    options: [
      { label: '是的', value: 1 },
      { label: '偶尔', value: 2 },
      { label: '不是', value: 3 },
    ]
  },
  // ---- 情感模型 E2 (题9-10) ----
  {
    id: 9, dim: 4, reverse: false,
    text: '我可以对天起誓，对待每一段感情我都付出了真心。',
    options: [
      { label: '并没有', value: 1 },
      { label: '也许？', value: 2 },
      { label: '是的！（问心无愧骄傲脸）', value: 3 },
    ]
  },
  {
    id: 10, dim: 4, reverse: false,
    text: '如果你的伴侣品德端正、温柔体贴、正直坦荡、学识渊博、谈吐得体、长相出众，内外都很优秀，你会是什么心情？',
    options: [
      { label: '就算ta再优秀我也不会陷入太深。', value: 1 },
      { label: '会介于A和C之间。', value: 2 },
      { label: '会非常珍惜ta，也许会变成恋爱脑。', value: 3 },
    ]
  },
  // ---- 情感模型 E3 (题11-12) ----
  {
    id: 11, dim: 5, reverse: false,
    text: '恋爱后，另一半特别黏人、时刻想陪着你，你内心感受如何？',
    options: [
      { label: '那很爽了', value: 1 },
      { label: '都行无所谓', value: 2 },
      { label: '我更喜欢保留独立空间', value: 3 },
    ]
  },
  {
    id: 12, dim: 5, reverse: false,
    text: '在任何一段关系中，我都很在意保留自己的私人空间。',
    options: [
      { label: '我更喜欢依赖与被依赖', value: 1 },
      { label: '看情况', value: 2 },
      { label: '是的！（斩钉截铁地说道）', value: 3 },
    ]
  },
  // ---- 态度模型 A1 (题13-14) ----
  {
    id: 13, dim: 6, reverse: false,
    text: '我相信大多数人内心都是善良的。',
    options: [
      { label: '其实邪恶的人心比世界上的痔疮更多。', value: 1 },
      { label: '也许吧。', value: 2 },
      { label: '是的，我愿相信好人更多。', value: 3 },
    ]
  },
  {
    id: 14, dim: 6, reverse: true, // ⚠️ 反题！A=3, C=1
    text: '路上遇到一个怎么看都超可爱的小女孩，不管用什么手机拍都很萌，她主动递来一根棒棒糖，你第一反应是？',
    options: [
      { label: '呜呜她真好真可爱！居然给我棒棒糖！', value: 3 },
      { label: '一脸懵逼，作挠头状', value: 2 },
      { label: '这也许是一种新型诈骗？还是走开为好。', value: 1 },
    ]
  },
  // ---- 态度模型 A2 (题15-16) ----
  {
    id: 15, dim: 7, reverse: false,
    text: '马上要考试，学校强制要求上晚自习，请假会扣分，但你已经约好和心仪对象一起玩《绝地求生》，你会怎么选择？',
    options: [
      { label: '翘了！反正就一次！', value: 1 },
      { label: '干脆请个假吧。', value: 2 },
      { label: '都快考试了还去啥。', value: 3 },
    ]
  },
  {
    id: 16, dim: 7, reverse: false,
    text: '我喜欢跳出固定规则，不喜欢被条条框框限制。',
    options: [
      { label: '认同', value: 1 },
      { label: '保持中立', value: 2 },
      { label: '不认同', value: 3 },
    ]
  },
  // ---- 态度模型 A3 (题17-18) ----
  {
    id: 17, dim: 8, reverse: false,
    text: '我做事情一般都会带着明确目标。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  {
    id: 18, dim: 8, reverse: false,
    text: '某天突然醒悟：人生根本没什么所谓的意义，人不过和动物一样被欲望支配，被激素牵着走，饿了吃、困了睡、有冲动就想靠近别人，和其他生物没本质区别。',
    options: [
      { label: '是这样的。', value: 1 },
      { label: '也许是，也许不是。', value: 2 },
      { label: '这简直是胡扯', value: 3 },
    ]
  },
  // ---- 行动驱力 Ac1 (题19-20) ----
  {
    id: 19, dim: 9, reverse: false,
    text: '我做事情更看重做出成绩、获得成长，而不是为了躲开麻烦和风险。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  {
    id: 20, dim: 9, reverse: false,
    text: '你在马桶上已经坐了30分钟，便秘难受又排不出，此时你的状态更像？',
    options: [
      { label: '再坐三十分钟看看，说不定就有了。', value: 1 },
      { label: '用力拍打自己的屁股并说："死屁股，快拉啊！"', value: 2 },
      { label: '使用开塞露，快点拉出来才好。', value: 3 },
    ]
  },
  // ---- 行动驱力 Ac2 (题21-22) ----
  {
    id: 21, dim: 10, reverse: false,
    text: '我做决定通常很干脆，不喜欢拖泥带水、反复纠结。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  {
    id: 22, dim: 10, reverse: false,
    text: '本题无题干，请直接盲选。',
    options: [
      { label: '反复思考后感觉应该选A？', value: 1 },
      { label: '啊，要不选B？', value: 2 },
      { label: '不会就选C？', value: 3 },
    ]
  },
  // ---- 行动驱力 Ac3 (题23-24) ----
  {
    id: 23, dim: 11, reverse: false,
    text: '当别人评价你"执行力很强"时，你内心更认同下面哪句话？',
    options: [
      { label: '我被逼到最后确实执行力超强...', value: 1 },
      { label: '啊，有时候吧。', value: 2 },
      { label: '是的，事情本来就该被推进', value: 3 },
    ]
  },
  {
    id: 24, dim: 11, reverse: false,
    text: '我做事通常会提前规划，____',
    options: [
      { label: '然而计划不如变化快。', value: 1 },
      { label: '有时能完成，有时不能。', value: 2 },
      { label: '我讨厌被打破计划。', value: 3 },
    ]
  },
  // ---- 社交模型 So1 (题25-26) ----
  {
    id: 25, dim: 12, reverse: false,
    text: '你因玩《第五人格》认识了不少网友，对方邀请你线下见面，你内心的真实想法是？',
    options: [
      { label: '网上口嗨下就算了，真见面还是有点忐忑。', value: 1 },
      { label: '见网友也挺好，反正谁来聊我就聊两句。', value: 2 },
      { label: '我会打扮一番并热情聊天，万一呢，我是说万一呢？', value: 3 },
    ]
  },
  {
    id: 26, dim: 12, reverse: false,
    text: '和朋友聚会时，对方还带了一位你不认识的人一起来，你最可能是什么状态？',
    options: [
      { label: '对"朋友的朋友"天然有点距离感，怕影响二人关系', value: 1 },
      { label: '看对方，能玩就玩。', value: 2 },
      { label: '朋友的朋友应该也算我的朋友！要热情聊天', value: 3 },
    ]
  },
  // ---- 社交模型 So2 (题27-28) ----
  {
    id: 27, dim: 13, reverse: true, // ⚠️ 反题！A=3, C=1
    text: '我和人相处习惯保持安全距离，一旦靠得太近就会下意识想后退。',
    options: [
      { label: '认同', value: 3 },
      { label: '中立', value: 2 },
      { label: '不认同', value: 1 },
    ]
  },
  {
    id: 28, dim: 13, reverse: false,
    text: '我特别希望和信任的人关系亲近，熟络得就像久别重逢的亲人。',
    options: [
      { label: '认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '不认同', value: 3 },
    ]
  },
  // ---- 社交模型 So3 (题29-30) ----
  {
    id: 29, dim: 14, reverse: false,
    text: '很多时候你对某件事明明有不同甚至负面的看法，却最终选择不说出口，主要原因是？',
    options: [
      { label: '这种情况较少。', value: 1 },
      { label: '可能碍于情面或者关系。', value: 2 },
      { label: '不想让别人知道自己是个阴暗的人。', value: 3 },
    ]
  },
  {
    id: 30, dim: 14, reverse: false,
    text: '我在不同的人面前，会展现出不一样的一面。',
    options: [
      { label: '不认同', value: 1 },
      { label: '中立', value: 2 },
      { label: '认同', value: 3 },
    ]
  },
  // ---- 隐藏题 ----
  {
    id: 31, dim: -1, reverse: false, // 特殊题，不计入维度
    text: '你平时都有哪些兴趣爱好？',
    options: [
      { label: '吃喝拉撒', value: 0 },
      { label: '艺术爱好', value: 0 },
      { label: '饮酒 🍺', value: -1 }, // 触发追加题
      { label: '健身', value: 0 },
    ]
  },
];

// 饮酒追加题
const DRINK_FOLLOWUP = {
  text: '那你平时喝酒的频率和方式是？',
  options: [
    { label: '偶尔小酌怡情', value: 0 },
    { label: '保温杯装白酒当白开水喝', value: -2 }, // 触发 DRUNK
    { label: '社交场合喝一点', value: 0 },
  ]
};

// ============ 25 种人格模板 ============
// 向量顺序: S1,S2,S3,E1,E2,E3,A1,A2,A3,Ac1,Ac2,Ac3,So1,So2,So3
// L=1, M=2, H=3
const PERSONALITY_TEMPLATES = [
  { index: 0,  code: 'CTRL',   name: '拿捏者', vector: [3,3,3,3,2,3,2,3,3,3,3,3,2,3,2] },
  { index: 1,  code: 'ATM-er', name: '送钱者', vector: [3,3,3,3,3,2,3,3,3,3,2,3,2,3,1] },
  { index: 2,  code: 'Dior-s', name: '屌丝',   vector: [2,3,2,2,2,3,2,3,2,3,2,3,1,3,1] },
  { index: 3,  code: 'BOSS',   name: '领导者', vector: [3,3,3,3,2,3,2,2,3,3,3,3,1,3,1] },
  { index: 4,  code: 'THAN-K', name: '感恩者', vector: [2,3,2,3,2,2,3,3,2,2,2,3,2,3,1] },
  { index: 5,  code: 'OH-NO',  name: '哦不人', vector: [3,3,1,1,2,3,1,3,3,3,3,2,1,3,1] },
  { index: 6,  code: 'GOGO',   name: '行者',   vector: [3,3,2,3,2,3,2,2,3,3,3,3,2,3,2] },
  { index: 7,  code: 'SEXY',   name: '尤物',   vector: [3,2,3,3,3,1,3,2,2,3,2,2,3,1,3] },
  { index: 8,  code: 'LOVE-R', name: '多情者', vector: [2,1,3,1,3,1,3,1,3,2,1,2,2,1,3] },
  { index: 9,  code: 'MUM',    name: '妈妈',   vector: [2,2,3,2,3,1,3,2,2,1,2,2,3,1,1] },
  { index: 10, code: 'FAKE',   name: '伪人',   vector: [3,1,2,2,2,1,2,1,2,2,1,2,3,1,3] },
  { index: 11, code: 'OJBK',   name: '无所谓人', vector: [2,2,3,2,2,2,3,2,1,1,2,2,2,2,1] },
  { index: 12, code: 'MALO',   name: '吗喽',   vector: [2,1,3,2,3,2,2,1,3,2,1,3,1,2,3] },
  { index: 13, code: 'JOKE-R', name: '小丑',   vector: [1,1,3,1,3,1,1,2,1,1,1,1,2,1,2] },
  { index: 14, code: 'WOC!',   name: '握草人', vector: [3,3,1,3,2,3,2,2,3,3,3,2,1,3,3] },
  { index: 15, code: 'THIN-K', name: '思考者', vector: [3,3,1,3,2,3,2,1,3,2,3,2,1,3,3] },
  { index: 16, code: 'SHIT',   name: '愤世者', vector: [3,3,1,3,1,3,1,2,2,3,3,2,1,3,3] },
  { index: 17, code: 'ZZZZ',   name: '装死者', vector: [2,3,1,2,1,3,1,2,1,2,2,1,1,3,2] },
  { index: 18, code: 'POOR',   name: '贫困者', vector: [3,3,1,2,1,3,1,2,3,3,3,3,1,3,1] },
  { index: 19, code: 'MONK',   name: '僧人',   vector: [3,3,1,1,1,3,1,1,2,2,2,1,1,3,2] },
  { index: 20, code: 'IMSB',   name: '傻者',   vector: [1,1,2,1,2,2,1,1,1,1,1,1,2,1,2] },
  { index: 21, code: 'SOLO',   name: '孤儿',   vector: [1,2,1,1,1,3,1,3,1,1,2,1,1,3,2] },
  { index: 22, code: 'FUCK',   name: '草者',   vector: [2,1,1,1,3,1,1,1,2,2,1,1,3,1,3] },
  { index: 23, code: 'DEAD',   name: '死者',   vector: [1,1,1,1,1,2,1,2,1,1,1,1,1,3,2] },
  { index: 24, code: 'IMFW',   name: '废物',   vector: [1,1,3,1,3,1,1,2,1,1,1,1,2,1,1] },
];

// ============ 核心算法 ============

/**
 * 计算15维度得分
 * @param {number[]} answers - 30道题的选项值数组 (索引0-29)
 * @returns {number[]} 15个维度的 L/M/H 值 (1/2/3)
 */
function calculateDimensions(answers) {
  const dimScores = new Array(15).fill(0);
  
  // 每个维度2道题，累加得分
  for (let i = 0; i < 30; i++) {
    const q = QUESTIONS[i];
    if (q.dim >= 0) {
      dimScores[q.dim] += answers[i];
    }
  }
  
  // 转换为 L/M/H
  return dimScores.map(score => {
    if (score <= 3) return 1; // L
    if (score === 4) return 2; // M
    return 3; // H
  });
}

/**
 * 曼哈顿距离匹配
 * @param {number[]} userVector - 用户15维向量 [1-3, 1-3, ...]
 * @returns {{ personality: object, similarity: number, distance: number, exactHits: number, allResults: object[] }}
 */
function matchPersonality(userVector) {
  const results = PERSONALITY_TEMPLATES.map(template => {
    let distance = 0;
    let exactHits = 0;
    
    for (let i = 0; i < 15; i++) {
      const diff = Math.abs(userVector[i] - template.vector[i]);
      distance += diff;
      if (diff === 0) exactHits++;
    }
    
    const similarity = Math.max(0, Math.round((1 - distance / 30) * 100));
    
    return {
      ...template,
      distance,
      exactHits,
      similarity,
    };
  });
  
  // 排序: 距离升序 → 精准命中降序 → 相似度降序
  results.sort((a, b) => {
    if (a.distance !== b.distance) return a.distance - b.distance;
    if (a.exactHits !== b.exactHits) return b.exactHits - a.exactHits;
    return b.similarity - a.similarity;
  });
  
  return {
    personality: results[0],
    similarity: results[0].similarity,
    distance: results[0].distance,
    exactHits: results[0].exactHits,
    allResults: results.slice(0, 5), // 返回 top 5
  };
}

/**
 * 完整测试流程
 * @param {number[]} answers - 30道基础题答案 (每题 1/2/3)
 * @param {boolean} isDrunk - 是否触发了酒鬼彩蛋
 * @returns {{ code: string, name: string, index: number, similarity: number, dimensions: number[], dimLabels: string[] }}
 */
function runSBTI(answers, isDrunk = false) {
  // 彩蛋1: 酒鬼 → 强制覆盖
  if (isDrunk) {
    const dims = calculateDimensions(answers);
    return {
      code: 'DRUNK',
      name: '酒鬼',
      index: 26,
      similarity: 100,
      dimensions: dims,
      dimLabels: dims.map(d => d <= 1 ? 'L' : d === 2 ? 'M' : 'H'),
    };
  }
  
  // 正常流程
  const dims = calculateDimensions(answers);
  const result = matchPersonality(dims);
  
  // 彩蛋2: 匹配度 < 60% → 傻乐者兜底
  if (result.similarity < 60) {
    return {
      code: 'HHHH',
      name: '傻乐者',
      index: 25,
      similarity: result.similarity,
      dimensions: dims,
      dimLabels: dims.map(d => d <= 1 ? 'L' : d === 2 ? 'M' : 'H'),
      fallback: true,
    };
  }
  
  return {
    code: result.personality.code,
    name: result.personality.name,
    index: result.personality.index,
    similarity: result.similarity,
    dimensions: dims,
    dimLabels: dims.map(d => d <= 1 ? 'L' : d === 2 ? 'M' : 'H'),
    topMatches: result.allResults,
  };
}

// 导出
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { QUESTIONS, DRINK_FOLLOWUP, DIMENSIONS, PERSONALITY_TEMPLATES, runSBTI, calculateDimensions, matchPersonality };
}
