// Wires up every .quiz-web on the page (website output). Each quiz is scoped
// to its own element, so several can coexist without interfering.
//
// Answers can be selected (optional, lets the participant commit mentally).
// The reveal button toggles the `revealed` state on the quiz: CSS then colours
// correct/incorrect answers (via data-correct) and unfolds the explanation.
(function () {
	function initQuiz(quiz) {
		var answers = quiz.querySelectorAll(".quiz-answer");
		var button = quiz.querySelector(".quiz-reveal-btn");
		if (!button) return;

		answers.forEach(function (a) {
			a.addEventListener("click", function () {
				if (quiz.classList.contains("revealed")) return;
				a.classList.toggle("selected");
			});
		});

		// The two labels come from the filter as data attributes (configurable in
		// the metadata); without them the English defaults stand.
		var revealLabel = quiz.dataset.revealLabel || "Reveal";
		var hideLabel = quiz.dataset.hideLabel || "Hide";

		button.addEventListener("click", function () {
			var revealed = quiz.classList.toggle("revealed");
			button.textContent = revealed ? hideLabel : revealLabel;
		});
	}

	function init() {
		document.querySelectorAll(".quiz-web").forEach(initQuiz);
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", init);
	} else {
		init();
	}
})();
