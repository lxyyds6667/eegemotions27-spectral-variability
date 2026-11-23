# 第二阶段研究问题卡

## Research Question Card

**Question**  
在完全复用第一阶段参与者 folds、线性分类器和评价指标的前提下，向原有 70 个 whole-trial 频段功率特征中加入“trial 内五个连续片段的频段功率标准差”，能否稳定提高 27 类刺激条件的跨参与者解码表现？

**Type**  
Prespecified follow-up analysis（预先规定比较规则的后续分析）。原记录使用了 `Confirmatory` 一词。第一阶段已经使用过这五个参与者折，以下是查看第二阶段结果前写下的假设和判据。

**Hypothesis**  
第一阶段把整段 trial 压缩为每个通道、每个频段的一个平均功率，可能丢失了随视频进程变化的频谱信息。保留原来的 70 个 whole-trial 特征，再加入 `14 通道 × 5 频段 = 70` 个跨五段标准差特征，可能在不引入复杂模型的情况下提高跨参与者 macro-F1。

**Why it matters**

- 它直接诊断第一阶段的一个具体失败机制：不是先假设模型太简单，而是检验 whole-trial 平均是否压缩过度。
- 新特征仍然完全建立在 Fourier/Welch 分析上，容易解释，也与 Bhaskar 教授特别提到的 Fourier analysis 保持一致。
- 每个 trial 最终仍只有一行特征；五个片段不会成为五个独立样本，因此不会引入 trial-segment leakage。

**Current evidence**

- 第一阶段 70-feature baseline：macro-F1 `0.047984`，accuracy `5.310%`。
- 100 次参与者内结构化置换：macro-F1 均值 `0.035896`，最高值 `0.046553`。
- 结果对 5% 时长排除规则不敏感，但在推断 128/256 Hz 组之间存在明显异质性。
- 当前没有证据表明提高分类器复杂度本身能够解决问题。

**Missing evidence**

- trial 内频段功率是否存在可重复的时间变化。
- 这些时间变化能否跨参与者帮助区分 27 个刺激条件。
- 任何改善是否同时出现在多个 folds 和两个推断采样率组，而不是由一个子组或少数参与者驱动。

**Frozen method before viewing results**

1. 保留第一阶段的 70 个 whole-trial log absolute band-power 特征。
2. 按样本索引把每个完整 trial 划分为五个连续、互不重叠、长度尽量相等的片段；不丢弃剩余样本。
3. 每个片段使用与第一阶段相同的 2 s periodic Hann、50% overlap、0.5 Hz bin spacing 和五个频段边界。
4. 对每个通道和频段计算五个片段特征的样本标准差，新增 70 个 temporal-variability 特征；总特征数为 140。
5. 继续使用相同的 5 个参与者 folds、训练折标准化、one-vs-all linear logistic ECOC 和 `lambda = 0.001`。
6. 不根据测试结果选择片段数、窗口长度、频带、模型或正则化参数。
7. 保存 OOF prediction、fold-level paired difference、采样率组指标和完整结构化置换结果。

**Primary comparison**  
140-feature temporal-variability representation 与第一阶段 70-feature baseline 的 OOF macro-F1 差值。Accuracy 和 balanced accuracy 仅作为补充指标。

**What would support it**

- 聚合 OOF macro-F1 高于冻结的第一阶段 baseline；
- 五个参与者 folds 中至少四个的 paired macro-F1 difference 为正；
- 推断 128 Hz 与 256 Hz 两个子组的 macro-F1 都不低于各自第一阶段结果；
- 扩展模型的真实标签结果高于其自身 100 次结构化置换分布。

以上条件共同满足，才允许写成“时间变化特征提供了较稳定的额外预测信息”。

**What would falsify it**

- 聚合 macro-F1 不高于第一阶段；或
- 改善只出现在三个及以下 folds；或
- 聚合改善完全由一个推断采样率组贡献，另一个组下降；或
- 扩展结果没有超过其自身结构化置换分布。

出现上述任一情况，都不能宣称 temporal variability 改善了跨参与者解码。结果应保留，并把“whole-trial 平均压缩过度”视为未获支持。

**Minimal next action**  
先实现并测试一个只负责生成 70 个五段标准差特征的 MATLAB 函数。合成测试必须证明：五段振幅恒定的正弦信号产生接近零的 temporal variability，而五段振幅逐段变化的相同频率信号产生明显更大的对应频段 variability。测试通过后，才运行真实数据。

**Decision**  
Run experiment，但在任何真实数据建模前冻结本卡；第一阶段结果不再修改。

## 明确不做的事

- 不在这一阶段加入 CNN、Transformer 或模型排行榜。
- 不同时加入谱熵、1/f slope、连接性、通道选择和人口统计变量。
- 不把五个片段当作独立训练样本。
- 不以提高 aggregate accuracy 为唯一成功标准。
- 不因为第一次结果不理想而改变片段数或重新选择 folds。
