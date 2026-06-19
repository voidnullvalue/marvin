.PHONY: test install uninstall shell diff

test:
	./tests/run.sh

install:
	./install.sh

uninstall:
	./uninstall.sh

shell:
	MARVIN_LOGIN_SHOWN=1 bash --noprofile --rcfile ./marvinrc.sh -i

diff:
	git diff --check
	bash -n ./marvinrc.sh ./lib/*.sh ./compatibility/*.sh ./install.sh ./uninstall.sh ./tests/*.sh
