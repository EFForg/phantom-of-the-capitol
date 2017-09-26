$(function(){
  $('.contact-row').hide();
  $('#zip').parent().show();
  $('#zip').keyup(function(val){
    if($(this).val().length == 5){
      window.setTimeout(function(){
        $('.contact-row').show();
      },500);
    }
  });
});
