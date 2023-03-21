

   function areaPreSubmit(event) {
    this.request.params['field'] = document.getElementById('area').value;
   }

   function areaAdvancedPreSubmit(event) {
    const regex = /\[\d+\]/;
    var value = document.getElementById('area-advanced-form').value;
    if(value.match(regex)) value = value.replace(regex, "");
    this.request.params['field'] = value;
   }
   
   function formPreSubmit(event) {
     //ev.preventDefault();
     const data = form.serializeForm();
     const queryString = Object.keys(data).map((key) => {
             return key + '=' + data[key]
         }).join('&amp;');
     //const dataUrl = new URLSearchParams(new FormData(formAdv)).toString();
     //document.getElementById('output').innerHTML = "<p><b>FORM:</b> " + queryString + "</p></p><b>ADV:</b> " + dataUrl + "</p>";
     //document.getElementById('output').innerHTML = "<p><b>FORM:</b> " + queryString + "</p>";
     this.request.params['parameters'] = encodeURIComponent(queryString);
   }

  window.addEventListener('WebComponentsReady', () => {

//    const searchSimple = document.getElementById('search-simple');
//    searchSimple.addEventListener('iron-form-presubmit', areaPreSubmit);

    const searchAdvanced = document.getElementById('search-advanced');
    searchAdvanced.addEventListener('iron-form-presubmit', areaAdvancedPreSubmit);

    const queryAdvanced = document.getElementsByName('query-advanced');
    queryAdvanced.forEach(key => {
      key.addEventListener('iron-form-presubmit', areaAdvancedPreSubmit);
    });
    const form = document.getElementById('form');
    form.addEventListener('iron-form-presubmit', formPreSubmit);
 
 });
