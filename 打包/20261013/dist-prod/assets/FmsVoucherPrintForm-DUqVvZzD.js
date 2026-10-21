import{o as e,r as t}from"./rolldown-runtime-DAXXjFlN.js";import{$i as n,Ka as r,M as i,Na as a,P as o,Qa as s,Y as c,Z as l,aa as u,ao as d,ca as f,da as p,eo as m,fa as h,g,gt as ee,ht as _,ma as v,mo as y,ro as b,sa as x,wa as S,ya as C}from"./form-create-Dv_TP_4u.js";import{r as w}from"./useCache-BYiA5reP.js";import{t as T}from"./useMessage-v5N46w9j.js";import{t as E}from"./Dialog-BJGiz6j3.js";import{c as D,i as O,l as k}from"./format-xG62J839.js";import{n as A}from"./print-wxAYKYl0.js";var j=e(c()),M={A4:{width:210,height:297},B5:{width:176,height:250}},N=8,P=4,F={paperType:`B5`,orientation:`landscape`,width:250,height:176,marginLeft:0,marginTop:0,fontSize:16};function I(e,t,n){let{width:r,height:i}=H(n),a=N+n.marginTop,o=N+n.marginLeft;return V(`凭证打印`,R(t).map(t=>z(e,t)).join(``),`
        @page { size: ${r}mm ${i}mm; margin: ${a}mm ${N}mm ${N}mm ${o}mm; }
        .voucher-page { width: ${r}mm; min-height: ${i}mm; padding: 8mm; }
      `,n.fontSize)}function L(e,t,n){let r=n.map(B).join(``);return V(`凭证列表`,`
    <section class="voucher-list-page">
      <h1>凭证列表</h1>
      <div class="list-meta"><span>编制单位：${A(e)}</span><span>${A(t)}</span></div>
      <table class="voucher-list-table">
        <thead><tr><th>日期</th><th>凭证字号</th><th>摘要</th><th>科目</th><th>借方金额</th><th>贷方金额</th><th>制单人</th><th>审核人</th></tr></thead>
        <tbody>${r}</tbody>
      </table>
    </section>
  `,`@page { size: A3 landscape; margin: 8mm; } .voucher-list-page { width: 100%; padding: 4mm; }`,14)}function R(e){let t=[];return e.forEach(e=>{let n=Math.max(1,Math.ceil(e.entries.length/P));for(let r=0;r<n;r++){let i=e.entries.slice(r*P,r*P+P);for(;i.length<P;)i.push(void 0);t.push({voucher:e,entries:i,currentPage:r+1,totalPages:n})}}),t}function z(e,t){let{voucher:n,entries:r}=t,i=r.map(e=>`
        <tr>
          <td>${A(e?.digest)}</td>
          <td>${A(e?U(e):``)}</td>
          <td class="money">${e?.debitAmount?A(O(e.debitAmount)):``}</td>
          <td class="money">${e?.creditAmount?A(O(e.creditAmount)):``}</td>
        </tr>
      `).join(``);return`
    <section class="voucher-page">
      <h1>记账凭证</h1>
      <div class="title-double-line"></div>
      <div class="attachment-count">附单据&nbsp;&nbsp;${n.attachmentCount||``}&nbsp;&nbsp;张</div>
      <div class="voucher-meta">
        <span>单位：${A(e)}</span>
        <span>日期：${(0,j.default)(n.voucherTime).format(`YYYY年MM月DD日`)}</span>
        <span>凭证号：${A(n.voucherWordName)}-${n.voucherNumber}（${t.currentPage}/${t.totalPages}）</span>
      </div>
      <table class="voucher-table">
        <thead><tr><th>摘要</th><th>会计科目</th><th>借方金额</th><th>贷方金额</th></tr></thead>
        <tbody>${i}</tbody>
        <tfoot><tr><td colspan="2">合计：${A(k(Number(n.debitAmount)))}</td><td class="money">${A(O(n.debitAmount))}</td><td class="money">${A(O(n.creditAmount))}</td></tr></tfoot>
      </table>
      <div class="voucher-footer"><span>财务主管：</span><span>审核：${A(n.reviewerUserName)}</span><span>出纳：</span><span>制单：${A(n.creatorUserName)}</span></div>
    </section>
  `}function B(e){return`
    <tr>
      <td>${(0,j.default)(e.voucherTime).format(`YYYY-MM-DD`)}</td>
      <td>${A(e.voucherWordName)}-${e.voucherNumber}</td>
      <td>${e.entries.map(e=>`<div>${A(e.digest)}</div>`).join(``)}</td>
      <td>${e.entries.map(e=>`<div>${A(U(e))}</div>`).join(``)}</td>
      <td class="money">${e.entries.map(e=>`<div>${e.debitAmount?A(O(e.debitAmount)):``}</div>`).join(``)}</td>
      <td class="money">${e.entries.map(e=>`<div>${e.creditAmount?A(O(e.creditAmount)):``}</div>`).join(``)}</td>
      <td>${A(e.creatorUserName)}</td>
      <td>${A(e.reviewerUserName)}</td>
    </tr>
  `}function V(e,t,n,r){return`<!doctype html>
    <html lang="zh-CN">
      <head>
        <meta charset="UTF-8" />
        <title>${A(e)}</title>
        <style>
          * { box-sizing: border-box; }
          body { margin: 0; background: #eef0f3; color: #303133; font-family: Arial, "Microsoft YaHei", sans-serif; font-size: ${r}px; }
          ${n}
          .voucher-page, .voucher-list-page { box-sizing: border-box; margin: 16px auto; background: #fff; box-shadow: 0 2px 12px rgba(0, 0, 0, .12); page-break-after: always; }
          h1 { margin: 0; text-align: center; font-size: 30px; font-weight: 500; }
          .title-double-line { width: 200px; height: 6px; margin: 8px auto; border-top: 1px solid; border-bottom: 1px solid; }
          .attachment-count { margin-bottom: 6px; text-align: right; }
          .voucher-meta, .voucher-footer, .list-meta { display: flex; justify-content: space-between; gap: 16px; padding: 7px 0; }
          table { width: 100%; border-collapse: collapse; }
          th, td { border: 1px solid #303133; padding: 10px 8px; vertical-align: middle; }
          .voucher-table th:nth-child(1) { width: 28%; }
          .voucher-table th:nth-child(2) { width: 38%; }
          .voucher-table th:nth-child(3), .voucher-table th:nth-child(4) { width: 17%; }
          .voucher-table tbody tr { height: 54px; }
          .money { text-align: right; }
          .voucher-footer span { width: 25%; }
          .voucher-footer span:nth-child(2), .voucher-footer span:nth-child(3) { text-align: center; }
          .voucher-footer span:last-child { text-align: right; }
          .voucher-list-page h1 { margin-bottom: 12px; font-weight: 600; }
          .voucher-list-table th, .voucher-list-table td { padding: 8px 6px; }
          .voucher-list-table tr { page-break-inside: avoid; }
          @media print {
            body { background: #fff; }
            .voucher-page, .voucher-list-page { width: auto; min-height: auto; margin: 0; padding: 0; box-shadow: none; }
          }
        </style>
      </head>
      <body>
        <main>${t}</main>
      </body>
    </html>`}function H(e){let t=e.paperType===`CUSTOM`?{width:e.width,height:e.height}:M[e.paperType],n=Math.min(t.width,t.height),r=Math.max(t.width,t.height);return e.orientation===`landscape`?{width:r,height:n}:{width:n,height:r}}function U(e){return D(e.subjectCode,e.subjectName,e.auxiliaries.map(e=>e.name))}C(),s();var W={key:0,class:`mt-10px flex items-center gap-20px`},G={class:`flex items-center gap-8px [&_.el-input-number]:!w-72px`},K={class:`flex items-center gap-8px [&_.el-input-number]:!w-72px`},q={class:`flex items-center gap-20px`},J={class:`flex items-center gap-8px [&_.el-input-number]:!w-72px`},Y={class:`flex items-center gap-8px [&_.el-input-number]:!w-72px`},X={class:`flex items-center gap-8px [&_.el-input-number]:!w-72px`},Z=v({name:`FmsVoucherPrintForm`,__name:`FmsVoucherPrintForm`,setup(e,{expose:t}){let{wsCache:s}=w(),c=T(),v=d(!1),C=d(0),D=d(``),O=d([]),k=d({...F}),A=b({paperType:[{required:!0,message:`请选择打印类型`,trigger:`change`},{validator:(e,t,n)=>{if(k.value.paperType!==`CUSTOM`||k.value.width&&k.value.height){n();return}n(Error(`请输入自定义纸张的宽度和长度`))},trigger:`change`}]}),j=d(),M=d();function N(e,t,n){C.value=e,D.value=t,O.value=n,k.value={...F,...s.get(z(e))},v.value=!0,S(()=>j.value?.clearValidate())}async function P(){j.value&&await j.value.validate()&&(s.set(z(C.value),k.value),await L(I(D.value,O.value,k.value)),v.value=!1)}async function L(e){let t=M.value?.contentDocument,n=M.value?.contentWindow;!t||!n||(t.open(),t.write(e),t.close(),await t.fonts?.ready,n.focus(),n.print())}function R(e){let t=window.open(``,`_blank`);if(!t){c.warning(`浏览器阻止了新窗口，请允许弹出窗口后重试`);return}t.document.open(),t.document.write(e),t.document.close(),t.focus()}function z(e){return`fmsVoucherPrintSetting:${e}`}return t({open:N,printHtml:L,previewHtml:R}),(e,t)=>{let s=i,c=o,d=g,b=ee,S=_,C=l,w=E;return a(),f(n,null,[h(w,{modelValue:y(v),"onUpdate:modelValue":t[8]||=e=>m(v)?v.value=e:null,title:`凭证打印`,width:`500px`},{footer:r(()=>[h(C,{type:`primary`,onClick:P},{default:r(()=>[...t[23]||=[p(`保存并打印`,-1)]]),_:1}),h(C,{onClick:t[7]||=e=>v.value=!1},{default:r(()=>[...t[24]||=[p(`取 消`,-1)]]),_:1})]),default:r(()=>[h(S,{ref_key:`formRef`,ref:j,model:y(k),rules:y(A),"label-position":`top`,class:`[&_.el-form-item]:!mb-12px [&_.el-form-item__label]:!pb-2px`},{default:r(()=>[h(b,{label:`打印类型`,prop:`paperType`},{default:r(()=>[h(c,{modelValue:y(k).paperType,"onUpdate:modelValue":t[0]||=e=>y(k).paperType=e},{default:r(()=>[h(s,{value:`A4`},{default:r(()=>[...t[9]||=[p(`A4`,-1)]]),_:1}),h(s,{value:`B5`},{default:r(()=>[...t[10]||=[p(`B5`,-1)]]),_:1}),h(s,{value:`CUSTOM`},{default:r(()=>[...t[11]||=[p(`自定义纸张`,-1)]]),_:1})]),_:1},8,[`modelValue`]),y(k).paperType===`CUSTOM`?(a(),f(`div`,W,[u(`div`,G,[t[12]||=u(`span`,null,`宽度`,-1),h(d,{modelValue:y(k).width,"onUpdate:modelValue":t[1]||=e=>y(k).width=e,controls:!1,min:1},null,8,[`modelValue`]),t[13]||=u(`span`,null,`毫米`,-1)]),u(`div`,K,[t[14]||=u(`span`,null,`长度`,-1),h(d,{modelValue:y(k).height,"onUpdate:modelValue":t[2]||=e=>y(k).height=e,controls:!1,min:1},null,8,[`modelValue`]),t[15]||=u(`span`,null,`毫米`,-1)])])):x(``,!0)]),_:1}),h(b,{label:`图像方向`},{default:r(()=>[h(c,{modelValue:y(k).orientation,"onUpdate:modelValue":t[3]||=e=>y(k).orientation=e},{default:r(()=>[h(s,{value:`portrait`},{default:r(()=>[...t[16]||=[p(`纵向`,-1)]]),_:1}),h(s,{value:`landscape`},{default:r(()=>[...t[17]||=[p(`横向`,-1)]]),_:1})]),_:1},8,[`modelValue`])]),_:1}),h(b,{label:`边框调整`},{default:r(()=>[u(`div`,q,[u(`div`,J,[t[18]||=u(`span`,null,`左`,-1),h(d,{modelValue:y(k).marginLeft,"onUpdate:modelValue":t[4]||=e=>y(k).marginLeft=e,controls:!1,min:0},null,8,[`modelValue`]),t[19]||=u(`span`,null,`毫米`,-1)]),u(`div`,Y,[t[20]||=u(`span`,null,`上`,-1),h(d,{modelValue:y(k).marginTop,"onUpdate:modelValue":t[5]||=e=>y(k).marginTop=e,controls:!1,min:0},null,8,[`modelValue`]),t[21]||=u(`span`,null,`毫米`,-1)])])]),_:1}),h(b,{label:`字体大小`},{default:r(()=>[u(`div`,X,[h(d,{modelValue:y(k).fontSize,"onUpdate:modelValue":t[6]||=e=>y(k).fontSize=e,controls:!1,min:12,max:24},null,8,[`modelValue`]),t[22]||=u(`span`,null,`像素`,-1)])]),_:1})]),_:1},8,[`model`,`rules`])]),_:1},8,[`modelValue`]),u(`iframe`,{ref_key:`printIframeRef`,ref:M,class:`pointer-events-none fixed -left-9999px top-0 h-1px w-1px border-0 opacity-0`,title:`凭证打印`},null,512)],64)}}}),Q=t({default:()=>$}),$=Z;export{Q as n,L as r,$ as t};