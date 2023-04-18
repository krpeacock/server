document.querySelector("form")?.addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");

  const name = document.getElementById("name").value.toString();

  button.setAttribute("disabled", true);

  // Interact with foo actor, calling the greet method
  const res = await fetch(`/greet?name=${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
  });

  const greeting = await res.text();

  button.removeAttribute("disabled");

  document.getElementById("greeting").innerText = greeting;

  return false;
});
