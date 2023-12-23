const dialog = document.getElementById('dialogComment');
if(dialog) {
    pbEvents.subscribe('pb-results-received', 'search', function(ev) { 
        const comments = document.querySelectorAll('.lediir-comment');
        const dialog = document.getElementById('dialogComment');
        if (comments) { 
            comments.forEach(comment => {
                
                const button = comment.querySelector("button[type='submit']")
                button.addEventListener('click', () => {
                    comment.querySelector("paper-dialog-scrollable").innerHTML=`<p>SEZNAM</p>`;
                    comment.open();
                });
            });
        }
    });
};