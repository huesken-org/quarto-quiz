#!/usr/bin/env bash
#
# Golden-file tests for the quiz filter.
#
# A case is a directory under tests/cases/ with an `input.qmd` that names its
# format and the filter itself:
#
#     format: revealjs
#     filters: [quiz]
#
# It is rendered with quarto in a scratch directory, and one recording — exit
# code, rendered content, attached assets, warnings — is compared against
# `expected.txt`.
#
# Rendering with **quarto** and not just pandoc is the point: the revealjs shape
# leans on Quarto's panel layout and its fragment handling, and only a real
# render shows that the generated `layout=` still reaches Quarto's own pass.
#
# The content is what a reader sees: `<main>` for html, the slides div for
# RevealJS, the whole file for everything else.
#
#   tests/run.sh                  all cases
#   tests/run.sh latex reveal     only cases whose name contains a pattern
#   tests/run.sh --update         rewrite expected.txt (check the diff!)
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

command -v quarto >/dev/null || {
	printf 'quarto not on PATH\n' >&2
	exit 2
}

update=0 patterns=()
for arg in "$@"; do
	case "$arg" in
	--update) update=1 ;;
	-*)
		sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'
		exit 2
		;;
	*) patterns+=("$arg") ;;
	esac
done

# the part a reader sees — without quarto's head and script trappings
content() {
	local file=$1
	case "$file" in
	*.html)
		if grep -q '<div class="slides">' "$file"; then
			awk '/<div class="slides">/,/^    <\/div>$/' "$file"
		else
			awk '/<main/,/<\/main>/' "$file"
		fi |
			# quarto puts a MathJax style block into every speaker note; drop the
			# block, but keep whatever follows the closing tag
			sed -E '/<style type="text\/css">/,/<\/style>/{ /<\/style>/!d; s#^.*</style>##; }'
		;;
	*) cat "$file" ;;
	esac
}

pass=0 fail=0 failed=()

for dir in "$HERE"/cases/*/; do
	dir=${dir%/}
	name=${dir##*/}

	if [[ ${#patterns[@]} -gt 0 ]]; then
		hit=0
		for p in "${patterns[@]}"; do [[ "$name" == *"$p"* ]] && hit=1; done
		[[ $hit == 1 ]] || continue
	fi
	work=$(mktemp -d)
	cp -r "$HERE/../_extensions" "$dir/input.qmd" "$work/"

	(cd "$work" && QUARTO_PROJECT_DIR="$work" quarto render input.qmd) >"$work/out" 2>"$work/err"
	rc=$?
	rendered=$(ls "$work"/input.* 2>/dev/null | grep -v '\.qmd$' | head -1)

	{
		printf -- '--- exit %d\n' "$rc"
		printf -- '--- content %s\n' "${rendered##*/}"
		[[ -n $rendered ]] && content "$rendered"
		printf -- '--- assets\n'
		[[ -n $rendered ]] && grep -oE 'quiz[a-z-]*\.(css|js)' "$rendered" | sort -u
		printf -- '--- warnings\n'
		# a failed render explains itself; a good one reports only its warning
		# and error lines — quarto's own `(W)`/`(E)` and the `ERROR` line with
		# which a Lua filter reports a broken construct without aborting the
		# run
		if [[ $rc == 0 ]]; then
			grep -E '^(\((W|E)\)|ERROR|WARNING)' "$work/err"
		else
			cat "$work/err"
		fi
	} | sed -E \
		-e 's/\x1b\[[0-9;]*m//g' \
		-e "s#$work#TMP#g" \
		-e "s#$HERE#TESTS#g" \
>"$work/actual"

	[[ $update == 1 ]] && cp "$work/actual" "$dir/expected.txt"

	if diff -u "$dir/expected.txt" "$work/actual" >"$work/diff" 2>&1; then
		printf 'PASS %s\n' "$name"
		pass=$((pass + 1))
	else
		printf 'FAIL %s\n' "$name"
		sed 's/^/     /' "$work/diff"
		fail=$((fail + 1))
		failed+=("$name")
	fi
	rm -rf "$work"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail == 0 ]] || {
	printf 'failed: %s\n' "${failed[*]}"
	exit 1
}

