default: check

check: qgoda.schema.json default-config.json
	ajv -s qgoda.schema.json -d default-config.json

qgoda.schema.json: qgoda.schema.yaml
	yaml2json $< >$@

default-config.json: default-config.yaml
	jq . $< >$@

clean:
	rm -f .*.swp *.json

.PHONY:
.PHONY: check clean
