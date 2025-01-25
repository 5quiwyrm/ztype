# ALGORITHM

This documents explains the algorithm behind mana, which is the one used here. Zakkkk is the original inventor of this algorithm, credits to him.

## The task at hand

Consider the string `chdofea chcofea`. If we used a magic layout with the rule `do -> d*`, all of our bigram and trigram data would have to be generated again after we apply our magic rule.

This is what we thought, until Zakkkk came up with the idea of extended n-grams.

## Extended n-grams

The issue is that we would have to somehow know that the `ofe` in `chdofea` has to be transformed to `*fe`, but the same string in `chcofea` shouldn't be transformed. We can achieve this by storing one redundant character into the past, hence allowing us to differentiate `ofe` in `chdofea` from `ofe` in `chcofea`.
