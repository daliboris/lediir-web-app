const query = document.getElementById('query-for');
const facets = document.getElementById('facets');
const reset = document.getElementById('search-reset-button');
if (facets) { 
    facets.addEventListener('pb-custom-form-loaded', function(ev) {
        const elems = ev.detail.querySelectorAll('.facet');
        elems.forEach(facet => {
            facet.addEventListener('change', () => {
                const heading = facet.closest('h3');
                if (heading) {
                    facets._submit();
                }
            });
        });
    });
    if(reset) {
        reset.addEventListener('click', () => {
            const elems = facets.querySelectorAll('.facet');
            elems.forEach(facet => { 
                const table = facet.closest('table');
                if (table) { 
                    facet.checked = false;
                    const nested = table.querySelectorAll('.nested .facet').forEach(nested => {
                        if (nested != facet) {
                            nested.checked = false;
                        }
                    });
                }
            });
            /*
                        TODO: doesn't work yet
                        const query = document.getElementById('search-form');
                        if(query &amp;&amp; query.value !== "") {
                            query.value = "";
                            query._submit;
                        }
                        else {
                                facets._submit();
                        }
                        */
            facets._submit();
        });
    }
    if(query) {
        facets.addEventListener('pb-custom-form-loaded', function(ev) { 
            const search = document.getElementById('search-form');
            const inputs = search.querySelectorAll("input[type='hidden']");
            var text = "";
            inputs.forEach((input) => {
                const value = input.getAttribute("value");
                if(value != "") {
                    const key = (value == "headword") ? "search.areas.basic-fileds"  : "search.fields." + value;
                    const html = "<pb-i18n key=\"" + key + "\">" + value + "</pb-i18n>";
                    text += (text == "") ? html : "; " + html;
                }
              });
              query.innerHTML = "Dotaz pro: " +  text;
        });
    }
}
