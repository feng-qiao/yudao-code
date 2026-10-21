import{r as e}from"./rolldown-runtime-DAXXjFlN.js";import{Go as t,Ka as n,Na as r,Qa as i,Z as a,aa as o,ao as s,ca as c,da as l,fa as u,ma as d,mo as f,oa as p,sa as m,ut as h,wo as g,ya as _}from"./form-create-Dv_TP_4u.js";import{t as v}from"./Icon-DouZjIwV.js";import{n as y,t as b}from"./css-XVdihXNX.js";import{f as x}from"./utils-BP9GwBCh.js";import{t as S}from"./useMessage-v5N46w9j.js";import{C,Et as w}from"./index-DLTnjdAq.js";import{t as T}from"./Dialog-BJGiz6j3.js";import{c as E}from"./formatTime-tJzC0ZEQ.js";import{t as D}from"./DictTag-Dp1CfHOf.js";import{t as O}from"./download-BoyulgRb.js";import{t as k}from"./Barcode-CjbjnbGd.js";import{t as A}from"./barcode-I7jhuj1_.js";_(),i(),g();var j={class:`flex justify-center items-center min-h-200px p-20px bg-[#f5f7fa] rounded mb-20px`},M={key:0,class:`flex justify-center items-center`},N={class:`inline-block max-w-300px overflow-hidden text-ellipsis whitespace-nowrap break-all`},P=d({name:`BarcodeDetail`,__name:`BarcodeDetail`,setup(e,{expose:i}){let d=S(),g=s(!1),_=s(),P=s({});i({open:e=>{g.value=!0,P.value={...e}},openByBusiness:async(e,t,n,r)=>{g.value=!0;try{let i=await A.getBarcodeByBusiness(t,e);i?P.value={...i}:(P.value={bizType:t,bizId:e,bizCode:n,bizName:r,content:``},d.warning(`未找到对应条码数据`))}catch{P.value={bizType:t,bizId:e,bizCode:n,bizName:r,content:``},d.error(`加载条码数据失败`)}}});let F=()=>{if(!_.value){d.warning(`条码组件未加载`);return}let e=_.value.getImageBase64?.();if(!e){d.warning(`条码生成失败，无法打印`);return}let t=window.open(``,`_blank`);if(!t){d.error(`无法打开打印窗口，请检查浏览器设置`);return}try{let n=`<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>打印条码</title>
    <style>
      * { margin: 0; padding: 0; }
      body { font-family: Arial, sans-serif; padding: 20px; }
      .print-container { text-align: center; }
      .barcode-img { max-width: 100%; margin: 20px 0; }
      .info { margin-top: 20px; text-align: left; font-size: 12px; }
      .info p { margin: 5px 0; }
      @media print {
        body { padding: 0; }
        .print-container { padding: 20px; }
      }
    </style>
  </head>
  <body>
    <div class="print-container">
      <img src="${e}" class="barcode-img" alt="条码" />
      <div class="info">
        <p><strong>业务编码:</strong> ${x(P.value.bizCode||``)}</p>
        <p><strong>业务名称:</strong> ${x(P.value.bizName||``)}</p>
        <p><strong>条码内容:</strong> ${x(P.value.content||``)}</p>
      </div>
    </div>
  </body>
</html>`;t.document.write(n),t.document.close(),t.onload=()=>{setTimeout(()=>{t.print()},500)}}catch{d.error(`打印失败，请重试`)}},I=()=>{if(!_.value){d.warning(`条码组件未加载`);return}let e=_.value.getImageBase64?.();if(!e){d.warning(`条码生成失败，无法下载`);return}try{O.base64Image(e,`barcode_${P.value.bizCode||`unknown`}_${Date.now()}`),d.success(`下载成功`)}catch{d.error(`下载失败，请重试`)}},L=async()=>{let{bizType:e,bizId:t,bizCode:n,bizName:r}=P.value;if(!e||!t){d.warning(`缺少业务类型或业务编号，无法生成条码`);return}try{await A.createBarcode({bizType:e,bizId:t,bizCode:n||``,bizName:r||``}),d.success(`条码生成成功`);let i=await A.getBarcodeByBusiness(e,t);i&&(P.value={...i})}catch(e){d.error(e?.message||`条码生成失败，请重试`)}};return(e,i)=>{let s=w,d=D,x=y,S=h,O=b,A=v,R=a,z=T;return r(),p(z,{title:`查看条码`,modelValue:g.value,"onUpdate:modelValue":i[1]||=e=>g.value=e,width:`500px`},{footer:n(()=>[P.value.content?m(``,!0):(r(),p(R,{key:0,type:`warning`,onClick:L},{default:n(()=>[u(A,{icon:`ep:magic-stick`,class:`mr-5px`}),i[2]||=l(` 生成 `,-1)]),_:1})),u(R,{type:`primary`,onClick:F},{default:n(()=>[u(A,{icon:`ep:printer`,class:`mr-5px`}),i[3]||=l(` 打印 `,-1)]),_:1}),u(R,{onClick:I},{default:n(()=>[u(A,{icon:`ep:download`,class:`mr-5px`}),i[4]||=l(` 下载 `,-1)]),_:1}),u(R,{onClick:i[0]||=e=>g.value=!1},{default:n(()=>[...i[5]||=[l(`关 闭`,-1)]]),_:1})]),default:n(()=>[o(`div`,null,[o(`div`,j,[P.value.content?(r(),c(`div`,M,[u(k,{ref_key:`barcodeRef`,ref:_,content:P.value.content,format:P.value.format,width:400,height:150},null,8,[`content`,`format`])])):(r(),p(s,{key:1,description:`暂无条码数据`}))]),u(O,{column:1,border:``},{default:n(()=>[u(x,{label:`条码格式`,"label-align":`left`,align:`left`},{default:n(()=>[P.value.format?(r(),p(d,{key:0,type:f(C).MES_WM_BARCODE_FORMAT,value:P.value.format},null,8,[`type`,`value`])):m(``,!0)]),_:1}),u(x,{label:`业务类型`,"label-align":`left`,align:`left`},{default:n(()=>[P.value.bizType?(r(),p(d,{key:0,type:f(C).MES_WM_BARCODE_BIZ_TYPE,value:P.value.bizType},null,8,[`type`,`value`])):m(``,!0)]),_:1}),u(x,{label:`条码内容`,"label-align":`left`,align:`left`},{default:n(()=>[u(S,{content:P.value.content,placement:`top`},{default:n(()=>[o(`span`,N,t(P.value.content),1)]),_:1},8,[`content`])]),_:1}),u(x,{label:`业务编码`,"label-align":`left`,align:`left`},{default:n(()=>[l(t(P.value.bizCode||`-`),1)]),_:1}),u(x,{label:`业务名称`,"label-align":`left`,align:`left`},{default:n(()=>[l(t(P.value.bizName||`-`),1)]),_:1}),u(x,{label:`状态`,"label-align":`left`,align:`left`},{default:n(()=>[P.value.status===void 0?m(``,!0):(r(),p(d,{key:0,type:f(C).COMMON_STATUS,value:P.value.status},null,8,[`type`,`value`]))]),_:1}),u(x,{label:`创建时间`,"label-align":`left`,align:`left`},{default:n(()=>[l(t(f(E)(P.value.createTime)),1)]),_:1})]),_:1})])]),_:1},8,[`modelValue`])}}}),F=e({default:()=>I}),I=P;export{F as n,I as t};