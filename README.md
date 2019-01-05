# faceworths-tron-smart-contracts

It includes 

1. a TRC20 token contract, and 
2. a FaceWorthPollFactory contract

The FaceWorthPollFactory contract implements 

* a registrar for people to register their FaceWorth polls
* [Commitment Scheme](https://en.wikipedia.org/wiki/Commitment_scheme) for people to give score to faces while staking 100 TRX
* a rule to find winners by score
* a rule to distribute prize to winners
* a rule to reward tokens to FaceWorth poll and other participants who do not win.
* a rule to find top faces

### Different stages of a FaceWorth poll



### The rule to find winners

The winners are those whose score are closest to final average score. The ratio of winners is 38.2% (golden ratio). If there are 1000 participants, there will be 382 winners. 100 participants will have 38 winners. 10 participants will have 3 winners. 3 participants will have 1 winner.

The winners are selected based on their score. The ranking is based on

1. The closer the score is to final average, the higher rank
2. If a low score and a high score are the same distance to the final average, the high score has higher rank.
3. If the score is the same, the earlier who commits, the higher rank

E.g. 

- 10 participants give score 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, so the average score is 5.5, and the winners will be 6, 5, 7
- 10 participants give score 1, 2, 3, 4, 5, 6, 7, 8, 9, 15, so the average score is 6, and the winners will be 6, 7, 5
- 10 participants give score 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, so the average score is 8, and the winners will be the first 3 participants

### The rule to distribute prize

The prize will be based on winners' ranking. The higher the rank is, the bigger prize is. The minimum prize step is 1 TRX and the max is 100 TRX.

### The rule to reward tokens

### The rule to find top faces
