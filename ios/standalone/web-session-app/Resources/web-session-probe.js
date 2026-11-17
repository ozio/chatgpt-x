/* Evaluated only after return to our own top-level ChatGPT page. One request
 * per attempt. Private result is passed in-process, never via URL/log/file. */
(function(nonce){
  if(window!==window.top||location.protocol!=='https:'||location.hostname!=='chatgpt.com'||(location.port&&location.port!=='443'))return 'wrong_origin';
  if(typeof nonce!=='string'||!/^[a-f0-9]{32}$/.test(nonce))return 'bad_nonce';
  if(window.__OR6NativeAuth&&window.__OR6NativeAuth.nonce===nonce)return 'pending';
  var result={nonce:nonce,state:'pending',status:0};window.__OR6NativeAuth=result;
  var controller=typeof AbortController==='function'?new AbortController():null;
  window.__OR6SessionAbort=controller;
  var timer=setTimeout(function(){if(controller)controller.abort();result.state='network_error';},15000);
  (async function(){
    try{
      var r=await fetch('/api/auth/session',{credentials:'include',cache:'no-store',redirect:'error',signal:controller?controller.signal:undefined});
      result.status=r.status;if(!r.ok){result.state='no_session';return;}
      var j=await r.json();
      if(!j||!j.user||typeof j.accessToken!=='string'||!j.accessToken||j.accessToken.length>16384){result.state='no_session';return;}
      result.credential={accessToken:j.accessToken};result.state='available';
    }catch(e){result.state='network_error';}finally{clearTimeout(timer);}
  }());return 'started';
})
