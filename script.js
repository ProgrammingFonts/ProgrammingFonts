let [javascriptCode, pythonCode, clikeCode] = ["", "", ""];
async function loadFiles() {
  javascriptCode = await fetch('javascriptCode.txt').then(response => response.text());
  pythonCode = await fetch('pythonCode.txt').then(response => response.text());
  clikeCode = await fetch('clikeCode.txt').then(response => response.text());
  changeMode();
}
loadFiles();
var editor = CodeMirror.fromTextArea(document.getElementById("editor"), {
    lineNumbers: true,
    scrollbarStyle: "null",
    lineWrapping: true
});
var cElement = editor.getWrapperElement();
cElement.style.fontSize = (localStorage.getItem("font-size") ?? "24") + "px";
document.getElementById("font-size").value = localStorage.getItem("font-size") ?? "24";
document.getElementById("theme").value = localStorage.getItem("theme") ?? "default";
editor.setOption("theme", localStorage.getItem("theme") ?? "default");
document.getElementById("language").value = localStorage.getItem("selectedMode") ?? "javascript";
editor.setOption("mode", localStorage.getItem("selectedMode") ?? "javascript");
document.getElementById("line-wrap").checked = localStorage.getItem("lineWrap") === "true" ?? false;
editor.setOption("lineWrapping", localStorage.getItem("lineWrap") === "true" ?? false);
document.getElementById("line-number").checked = localStorage.getItem("lineNumbers") === "true" ?? true;
editor.setOption("lineNumbers", localStorage.getItem("lineNumbers") === "true" ?? true);

const changeMode = () => {
  const mode = document.getElementById("language").value;
  editor.setOption("mode", mode);
  if (mode === "python") {
      editor.setValue(pythonCode);
  }
  if (mode === "javascript") {
      editor.setValue(javascriptCode);
  }
  if (mode === "clike") {
      editor.setValue(clikeCode);
  }
  localStorage.setItem("selectedMode", mode);
};

const changeTheme = () => {
  const theme = document.getElementById("theme").value;
  editor.setOption("theme", theme);
  localStorage.setItem("theme", theme);
};

const changeSize = () => {
  const size = document.getElementById("font-size").value;
  cElement.style.fontSize = `${size}px`;
  localStorage.setItem("font-size", size);
};

const changeWrap = () => {
  const isChecked = document.getElementById("line-wrap").checked;
  editor.setOption("lineWrapping", isChecked);
  localStorage.setItem("lineWrap", isChecked);
};

const changeNum = () => {
  const isChecked = document.getElementById("line-number").checked;
  editor.setOption("lineNumbers", isChecked);
  localStorage.setItem("lineNumbers", isChecked);
};

function resetSettings() {
  localStorage.clear();
  document.getElementById("theme").value = "3024-night";
  document.getElementById("font-size").value = 24;
  document.getElementById("language").value = "javascript";
  document.getElementById("line-wrap").checked = true;
  document.getElementById("line-number").checked = true;
  changeTheme();
  changeSize();
  changeMode();
  changeWrap();
  changeNum();
}
