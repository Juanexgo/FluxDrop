(()=>{
const input=document.querySelector('#filter');
const rows=Array.from(document.querySelectorAll('tbody tr'));
input?.addEventListener('input',()=>{const q=input.value.trim().toLocaleLowerCase('es');let count=0;for(const row of rows){row.hidden=!(row.dataset.search??'').includes(q);if(!row.hidden)count++;}const status=document.querySelector('#count');if(status)status.textContent=`${count} operaciones encontradas`;});
})();
