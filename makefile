# These two files make up the test set
# Typical workflow: tweak code or input files, evaluate with
# $ make ok.txt
# and then examine errors with 
# $ diff -u pre-tokens.txt post-tokens.txt
# or visually with 
# $ make surv
# LHS = gold-standard, RHS = output of caighdeánaitheoir
TESTPRE=testpre.txt
TESTPOST=testpost.txt
TESTGA=testpost-gd.txt
TESTGD=testpre-gd.txt

all: ok.txt

# only if copyrighted material is added en masse
shuffle: FORCE
	paste $(TESTPRE) $(TESTPOST) | shuf | tee pasted.txt | cut -f 1 > newpre.txt
	cat pasted.txt | cut -f 2 > $(TESTPOST)
	mv -f newpre.txt $(TESTPRE)
	rm -f pasted.txt

# evaluate the algorithm that does nothing to the prestandard text!
baseline: FORCE
	@perl compare.pl $(TESTPOST) $(TESTPRE)
	@echo `cat unchanged.txt | wc -l` "out of" `cat $(TESTPRE) | wc -l` "unchanged"

baseline-gd: FORCE
	@perl compare.pl $(TESTGA) $(TESTGD)
	@echo `cat unchanged.txt | wc -l` "out of" `cat $(TESTGD) | wc -l` "unchanged"

# run pre-standardized text through the new code
tokenized-output.txt: $(TESTPRE) tiomanai.sh nasc.pl caighdean.pl rules.txt clean.txt pairs.txt ngrams.txt alltokens.pl pairs-local.txt spurious.txt multi.txt
	cat $(TESTPRE) | bash tiomanai.sh > $@

tokenized-output-gd.txt: $(TESTGD) tiomanai.sh nasc.pl caighdean.pl rules-gd.txt clean.txt pairs-gd.txt ngrams.txt alltokens.pl pairs-local-gd.txt spurious-gd.txt multi-gd.txt
	cat $(TESTGD) | bash tiomanai.sh -d > $@

nua-output.txt: tokenized-output.txt detokenize.pl
	cat tokenized-output.txt | sed 's/^.* => //' | perl detokenize.pl > $@

nua-output-gd.txt: tokenized-output-gd.txt detokenize.pl
	cat tokenized-output-gd.txt | sed 's/^.* => //' | perl detokenize.pl > $@

# doing full files is too slow
surv: FORCE
	head -n 10000 pre-tokens.txt > pre-surv.txt
	head -n 10000 post-tokens.txt > post-surv.txt
	vimdiff pre-surv.txt post-surv.txt

# compare.pl outputs unchanged.txt (set of sentences from
# testpost.txt that we got right),
# pre-tokens.txt (correct standardizations in sentences we got wrong),
# and post-tokens.txt (the standardizations we output)
ok.txt: nua-output.txt $(TESTPOST) compare.pl
	perl compare.pl $(TESTPOST) nua-output.txt
	echo `cat unchanged.txt | wc -l` "out of" `cat nua-output.txt | wc -l` "correct"
	mv unchanged.txt $@
	git diff $@

ok-gd.txt: nua-output-gd.txt $(TESTGA) compare.pl
	perl compare.pl $(TESTGA) nua-output-gd.txt
	echo `cat unchanged.txt | wc -l` "out of" `cat nua-output-gd.txt | wc -l` "correct"
	mv unchanged.txt $@
	git diff $@

# TODO: Add an independent test of detokenizer; use generic
# modern texts, not stuff from CCGB that may have already by detokenized once

eid-output.txt: tokenized-output.txt
	cat tokenized-output.txt | perl detokenize.pl > $@

clean:
	rm -f detokentest.txt unchanged.txt post-tokens.txt pre-tokens.txt tokenized-output.txt tokenized-output-gd.txt nua-output.txt nua-output-gd.txt cga-output.txt pre-surv.txt post-surv.txt tofix.txt survey.txt probsleft.txt tofixgram.txt

############## Build test sets from CCGG ###############

ccgg-refresh: FORCE
	find ${HOME}/gaeilge/ga2gd/ccgg -type f | egrep -v -- '-b$$' | egrep -v '/po-m[a-z][a-z]t$$' | while read x; do paste $$x $$x-b | sed 's/^[^:]*: *//' | sed 's/\t[^:]*: */\t/'; done | shuf | tee pasted.txt | cut -f 1 > $(TESTGA)
	cat pasted.txt | cut -f 2 > $(TESTGD)
	rm -f pasted.txt

############## COMPARISON WITH RULE-BASED VERSION ONLY ###############

cga-output.txt: tokenized-output.txt
	cat $(TESTPRE) | cga > $@

cgaeval: cga-output.txt FORCE
	perl compare.pl $(TESTPOST) cga-output.txt
	echo `cat unchanged.txt | wc -l` "out of" `cat cga-output.txt | wc -l` "correct"

############## SURVEY OF UNKNOWN WORDS ###############

# in testpost.txt; use this output to further standardize testpost.txt manually
tofix.txt: FORCE
	cat testpost.txt | sed "s/\([A-Za-z]\)’\([A-Za-zÁÉÍÓÚáéíóú]\)/\1'\2/g" | perl -I ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/lib ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/scripts/gram-ga.pl --ionchod=utf-8 --litriu | LC_ALL=C sort | LC_ALL=C uniq -c | LC_ALL=C sort -r -n > $@

tofixgram.txt: FORCE
	cat testpost.txt | sed "s/\([A-Za-z]\)’\([A-Za-zÁÉÍÓÚáéíóú]\)/\1'\2/g" | perl -I ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/lib ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/scripts/gram-ga.pl --ionchod=utf-8 --api | perl ${HOME}/gaeilge/gramadoir/gr/bin/api2old | egrep -o 'errortext="[^"]+"' | sed 's/^errortext="//' | sed 's/"$$//' | LC_ALL=C sort | LC_ALL=C uniq -c | LC_ALL=C sort -r -n > $@

# in nua-output.txt; use this to add to backend database: rules and pairs
# nua-output.txt shouldn't contain word-internal unicode apostrophes
survey.txt: nua-output.txt
	cat nua-output.txt | perl -I ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/lib ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/scripts/gram-ga.pl --ionchod=utf-8 --litriu | LC_ALL=C sort | LC_ALL=C uniq -c | LC_ALL=C sort -r -n > $@

# similar to survey, but catches context-sensitive non-standard bits too, 
# like "go dtáinig", "i n-áit" and so on
# often these arise because they appear frequently in n-gram model -
# add them to cleanup.sh in that dir
probsleft.txt: nua-output.txt
	cat nua-output.txt | perl -I ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/lib ${HOME}/gaeilge/gramadoir/gr/ga/Lingua-GA-Gramadoir/scripts/gram-ga.pl --ionchod=utf-8 --api | perl ${HOME}/gaeilge/gramadoir/gr/bin/api2old | egrep -o 'errortext="[^"]+"' | sed 's/^errortext="//' | sed 's/"$$//' | LC_ALL=C sort | LC_ALL=C uniq -c | LC_ALL=C sort -r -n > $@

PUL.txt: FORCE
	rm -f $@
	find ${HOME}/gaeilge/diolaim/sean/ria -name '?M*' | egrep -v nua | xargs egrep -l '^<U.+(Athair Peadar|Rev. Peter)' | egrep -v '(LM17[345]|LM088)' | xargs cat | sed 's/<[^>]*>//g' > $@

############## TARGETS FOR MAINTAINER ONLY ! ###############
GAELSPELL=${HOME}/gaeilge/ispell/ispell-gaeilge
CRUBLOCAL=${HOME}/gaeilge/crubadan/crubadan
GRAMADOIR=${HOME}/gaeilge/gramadoir/gr/ga
CRUB=/usr/local/share/crubadan
NGRAM=${HOME}/gaeilge/ngram
GA2GD=${HOME}/gaeilge/ga2gd/ga2gd

# rules.txt currently locally modified - don't refresh from gramadoir!
# do "make refresh" right after running "groom"
refresh: clean.txt-refresh pairs.txt-refresh ngrams.txt-refresh alltokens.pl-refresh

groom: pairs.txt-refresh clean.txt-refresh

# removed gaelu for RIA May 2014; doesn't make sense if trying to mimic
# a human standardizing a pre-standard Irish book for example
pairs.txt-refresh: $(GAELSPELL)/apost $(GAELSPELL)/athfhocail $(GAELSPELL)/earraidi
	rm -f pairs.txt
	LC_ALL=C sort -u $(GAELSPELL)/apost $(GAELSPELL)/athfhocail $(GAELSPELL)/earraidi | sort -k1,1 > pairs.txt
	chmod 444 pairs.txt

pairs-gd.txt-refresh: FORCE
	rm -f pairs-gd.txt
	(cd $(GA2GD); make pairs-gd.txt)
	cp $(GA2GD)/pairs-gd.txt .
	chmod 444 pairs-gd.txt

ngrams.txt-refresh: FORCE
	rm -f ngrams.txt
	(cd $(NGRAM); make ga-model.txt)
	cp -f $(NGRAM)/ga-model.txt ngrams.txt
	chmod 444 ngrams.txt

# GLAN==aspell.txt, LEXICON=GLAN + proper names, etc.
# ispell personal, uimhreacha, apost; .ispell_gaeilge; dinneenok.txt
clean.txt-refresh: $(CRUB)/ga/LEXICON
	rm -f clean.txt
	cat $(CRUB)/ga/LEXICON | sort -u > clean.txt
	chmod 444 clean.txt

rules.txt-refresh: $(GRAMADOIR)/morph-ga.txt
	rm -f rules.txt
	cat $(GRAMADOIR)/morph-ga.txt | iconv -f iso-8859-1 -t utf8 | egrep -v '^#' | sed '/^\^h?an-(\[bcfgmp\]h/,/eachtar.freas/s/^/#/' | sed '/^(\.\[aouáóú/,/^(\[eiéí.*-ne/s/^/#/' | sed '/íní?/s/^/#/' | sed '/\[bdm\]/s/^/#/' | sed '/^\^do(/,/^\^h?in(\[\^/s/^/#/' | sed '/^fa\?ir/s/idh/idh_tú/' | sed '/^\^mb/r rules-local.txt' | sed 's/^\([^ \t]*\)[ \t]*\([^ \t]*\)[ \t]*\([^ \t]*\).*/\1\t\2\t\3/' > rules.txt
	chmod 444 rules.txt

alltokens.pl-refresh: $(CRUBLOCAL)/alltokens.pl
	rm -f alltokens.pl
	cp $(CRUBLOCAL)/alltokens.pl alltokens.pl
	chmod 444 alltokens.pl

# don't wipe rules.txt - locally modified
maintainer-clean:
	$(MAKE) clean
	rm -f clean.txt pairs.txt ngrams.txt alltokens.pl

FORCE:
