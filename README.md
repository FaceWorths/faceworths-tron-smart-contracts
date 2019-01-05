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

### Different stages of a FaceWorth poll game

A FaceWorth poll game starts with Commit stage, move to Reveal stage and then Ended stage, or move to Cancelled stage if there are less than 3 players during Commit stage.

### The rule to find winners

The winners are those whose score are closest to final average score. The ratio of winners is 38.2% (golden ratio). If there are 1000 participants, there will be 382 winners. 100 participants will have 38 winners. 10 participants will have 3 winners. 3 participants will have 1 winner.

The winners are selected based on their score, so if a player only commits but does not reveal score, she/he will not be selected as winner. The ranking is based on

1. The closer the score is to final average, the higher rank.
2. If a low score and a high score are the same distance to the final average, the high score has higher rank.
3. If the score is the same, the earlier who commits, the higher rank.

E.g. 

- 10 participants give score 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, so the average score is 5.5, and the winners will be 6, 5, 7
- 10 participants give score 1, 2, 3, 4, 5, 6, 7, 8, 9, 15, so the average score is 6, and the winners will be 6, 7, 5
- 10 participants give score 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, so the average score is 8, and the winners will be the first 3 participants

### The rule to distribute prize

The prize will be based on winners' ranking. The higher the rank is, the bigger prize is. The minimum prize step is 1 TRX and the max step is 100 TRX.
85% of total stake will go to winners. E.g. 

Assuming every player reveals their score,
- When there are 6 players, total stake will be 600 TRX, 85% of which (510 TRX) will go to 2 winners. Lowest prize will be 205 TRX, highest prize will be 305 TRX, prize step is 100 TRX.
- When there are 618 players, total stake will 61800 TRX, 85% of which (52530 TRX) will go to 236 winners. Lowest prize will be 105 TRX, second lowest prize will be 106 TRX, ..., highest prize will be 340 TRX, prize step is 1.

If a player only commits but does not reveal the score, she/he will lose the stake, and 85% of her/his stake will go to prize pool.


### The rule to reward FACE tokens

The FaceWorth poll game creator will receive 10 FACE tokens, and then 0.382 tokens per player. Say if there are 100 players, the game creator will receive 48.2 FACE tokens. 

Each game player will receive 6.18 FACE tokens if she/he does not win any TRX.

If a game is cancelled because there are less than 3 players, then neither game creator or game players will receive any token.

### The rule to find top faces

We count not only average score of a face but also how many people who give scores. The final score is calculated as
* Final_Score = Average_Score * Sqrt (Players * 10). 

E.g., if a game has 10 players, but only 8 of them reveal their scores. The total score of the 8 is 720. Then the Average score is 720 / 8 = 90, and the final score will be 90 * Sqrt (10 * 10) = 900. 
All faces will be ranked based on the final score calculated.
