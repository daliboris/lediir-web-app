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
}
