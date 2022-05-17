(this["webpackJsonpjava-analyzer-frontend"]=this["webpackJsonpjava-analyzer-frontend"]||[]).push([[0],{364:function(e,t,a){},487:function(e,t){},535:function(e,t,a){"use strict";a.r(t);var r=a(0),n=a.n(r),o=a(15),c=a.n(o),s=(a(364),a(615)),i=a(614),l=a(28),j=a(124),u=a(327),m=function(e){var t=arguments.length>1&&void 0!==arguments[1]?arguments[1]:{};t.headers||(t.headers=new Headers({Accept:"application/json"}));var a=localStorage.getItem("token");return t.headers.set("Authorization","Bearer ".concat(a)),j.a.fetchJson(e,t)},d=Object(u.a)("http://www.detachmentsoft.top/rest",m),b=Object(l.a)(Object(l.a)({},d),{},{create:function(e,t){if("JobCreateReq"!==t.data.createReq)return d.create(e,t);var a=new FormData;return a.append("parsetype",t.data.parsetype),a.append("file",t.data.file.rawFile),m("".concat("http://www.detachmentsoft.top","/parsedump"),{method:"POST",body:a}).then((function(e){var a=e.json;return{data:Object(l.a)(Object(l.a)({},t.data),{},{id:a.id})}}))}}),p={login:function(e){var t=e.username,a=e.password,r=new Request("http://www.detachmentsoft.top/rest/rpc/login",{method:"POST",body:JSON.stringify({email:t,password:a}),headers:new Headers({"Content-Type":"application/json",Accept:"application/vnd.pgrst.object+json",Prefer:"return=representation"})});return fetch(r).then((function(e){if(e.status<200||e.status>=300)throw new Error(e.statusText);return e.json()})).then((function(e){var t=e.me,a=e.token;localStorage.setItem("token",a),localStorage.setItem("me",JSON.stringify(t))}))},checkError:function(e){var t=e.status;return 401===t||403===t?(localStorage.removeItem("token"),localStorage.removeItem("me"),Promise.reject()):Promise.resolve()},checkAuth:function(){return localStorage.getItem("token")?Promise.resolve():Promise.reject()},logout:function(){return localStorage.removeItem("token"),localStorage.removeItem("me"),Promise.resolve()},getIdentity:function(){try{var e=JSON.parse(localStorage.getItem("me")),t=e.id,a=e.name;e.email,e.role;return Promise.resolve({id:t,fullName:a})}catch(r){return Promise.reject(r)}},getPermissions:function(){var e=JSON.parse(localStorage.getItem("me")).role;return e?Promise.resolve(e):Promise.reject()}},h=a(616),O=a(617),f=a(609),v=a(610),x=a(307),g=a(620),y=a(618),w=a(619),P=a(621),k=a(613),T=a(172),N=a(13),S=a.n(N),J=a(96),C=a(591),I=a(117),D=a(68),F=a(215),z=a(151),L=a.n(z),R=a(18),A=Object(F.a)({link:{textDecoration:"none"},icon:{width:"0.5em",height:"0.5em",paddingLeft:2}}),_=Object(r.memo)((function(e){var t=e.className,a=e.emptyText,r=e.source,n=e.linkText,o=Object(T.a)(e,["className","emptyText","source","linkText"]),c=Object(I.b)(e),s=S()(c,r),i=A();return null==s?Object(R.jsx)(J.a,Object(l.a)(Object(l.a)({component:"span",variant:"body2",className:t},Object(D.a)(o)),{},{children:a})):Object(R.jsxs)(C.a,Object(l.a)(Object(l.a)({className:i.link,href:s,variant:"body2"},Object(D.a)(o)),{},{children:[n,Object(R.jsx)(L.a,{className:i.icon})]}))}));_.defaultProps={addLabel:!0},_.displayName="UrlFieldWithCustomLinkText";var q=_,H=Object(F.a)({link:{textDecoration:"none"},icon:{width:"0.5em",height:"0.5em",paddingLeft:2}}),B=Object(r.memo)((function(e){var t=e.className,a=e.emptyText,r=e.source,n=(e.linkText,Object(T.a)(e,["className","emptyText","source","linkText"])),o=Object(I.b)(e),c=S()(o,r),s=H();return null==c?Object(R.jsx)(J.a,Object(l.a)(Object(l.a)({component:"span",variant:"body2",className:t},Object(D.a)(n)),{},{children:a})):Object(R.jsxs)(C.a,Object(l.a)(Object(l.a)({className:s.link,href:c,variant:"body2"},Object(D.a)(n)),{},{children:[c.split("/").pop(),Object(R.jsx)(L.a,{className:s.icon})]}))}));B.defaultProps={addLabel:!0},B.displayName="UrlFieldWithLastFileNameAsLinkText";var E=B,U=function(e){return Object(R.jsx)(h.a,Object(l.a)(Object(l.a)({},e),{},{children:Object(R.jsxs)(O.a,{children:[Object(R.jsx)(f.a,{source:"payload.tag",label:"Parse Type"}),Object(R.jsx)(E,{source:"payload.contents.contents",download:!0,label:"Dump File"}),Object(R.jsx)(v.a,{source:"created_at",showTime:!0,locales:"zh-CN",options:{hour12:!1}}),Object(R.jsx)(v.a,{source:"run_at",showTime:!0,locales:"zh-CN",options:{hour12:!1}}),Object(R.jsx)(v.a,{source:"updated_at",showTime:!0,locales:"zh-CN",options:{hour12:!1}}),Object(R.jsx)(f.a,{source:"status"}),Object(R.jsx)(q,{source:"last_update.report_url",linkText:"Report",target:"_blank",label:"Report"})]})}))},W=[Object(x.c)(),Object(x.a)(["ParseJavaCore","ParseHeapDump"],"Please choose one of the values")],M=[Object(x.c)()],G=function(e){return Object(l.a)(Object(l.a)({},e),{},{createReq:"JobCreateReq"})},K=function(e){return Object(R.jsx)(g.a,Object(l.a)(Object(l.a)({},e),{},{transform:G,children:Object(R.jsxs)(y.a,{children:[Object(R.jsx)(w.a,{source:"parsetype",choices:[{id:"ParseJavaCore",name:"Java Core"},{id:"ParseHeapDump",name:"Heap Dump"}],validate:W}),Object(R.jsx)(P.a,{source:"file",label:"Java Dump File",multiple:!1,minSize:0,maxSize:1e9,placeholder:Object(R.jsx)("p",{children:"Drop your java dump file here"}),validate:M,children:Object(R.jsx)(k.a,{source:"src",title:"title"})})]})}))},Q=function(){return Object(R.jsx)(s.a,{disableTelemetry:!0,title:"Java Dump Analyzer",dataProvider:b,authProvider:p,children:Object(R.jsx)(i.a,{name:"jobs",list:U,create:K})})},V=function(e){e&&e instanceof Function&&a.e(3).then(a.bind(null,628)).then((function(t){var a=t.getCLS,r=t.getFID,n=t.getFCP,o=t.getLCP,c=t.getTTFB;a(e),r(e),n(e),o(e),c(e)}))};c.a.render(Object(R.jsx)(n.a.StrictMode,{children:Object(R.jsx)(Q,{})}),document.getElementById("root")),V()}},[[535,1,2]]]);
//# sourceMappingURL=main.261f013b.chunk.js.map