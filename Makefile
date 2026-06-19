.PHONY: test install shell diff

test:
	./tests/smoke.sh

install:
	./install.sh

shell:
	MARVIN_LOGIN_SHOWN=1 bash --noprofile --rcfile ./marvinrc.sh -i

diff:
	git diff --check
	bash -n ./marvinrc.sh
