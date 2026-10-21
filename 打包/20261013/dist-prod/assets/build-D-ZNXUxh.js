import"./rolldown-runtime-DAXXjFlN.js";import{$i as e,Aa as t,Go as n,Ka as r,La as i,Na as a,Qa as o,Ra as s,Z as c,aa as l,ao as u,at as d,ca as f,da as p,eo as m,fa as h,ma as g,mo as _,n as v,qa as y,sa as b,wo as x,ya as S}from"./form-create-Dv_TP_4u.js";import{t as C}from"./useI18n-BipKiBzy.js";import{f as w}from"./is-55mMX162.js";import{t as T}from"./useMessage-v5N46w9j.js";import{L as E,f as D}from"./index-DLTnjdAq.js";import{t as O}from"./Dialog-BJGiz6j3.js";import{t as k}from"./ContentWrap-sUAXl6Mj.js";import{t as A}from"./es-DIiO_hLg.js";/* empty css               */import{t as j}from"./java-CmNV-nTB.js";import{t as M}from"./json-CCpEOlaT.js";S(),o(),x();var N={class:`h-[calc(100vh-var(--top-tool-height)-var(--tags-view-height)-var(--app-content-padding)-var(--app-content-padding)-2px)]`},P={key:0,ref:`editor`},F={class:`hljs`},I=g({name:`InfraBuild`,__name:`index`,setup(o){let{t:g}=C(),x=T(),S=u({switchType:[],autoActive:!0,useTemplate:!1,formOptions:{form:{labelWidth:`100px`}},fieldReadonly:!1,hiddenDragMenu:!1,hiddenDragBtn:!1,hiddenMenu:[],hiddenItem:[],hiddenItemConfig:{},disabledItemConfig:{},showSaveBtn:!1,showConfig:!0,showBaseForm:!0,showControl:!0,showPropsForm:!0,showEventForm:!0,showValidateForm:!0,showFormConfig:!0,showInputData:!0,showDevice:!0,appendConfigData:[]}),I=u(),L=u(!1),R=u(``),z=u(-1),B=u(``);E(I);let V=e=>{L.value=!0,R.value=e},H=()=>{V(`生成 JSON`),z.value=0,B.value=I.value.getRule()},U=()=>{V(`生成 Options`),z.value=1,B.value=I.value.getOption()},W=()=>{V(`生成组件`),z.value=2,B.value=G()},G=()=>{let e=I.value.getRule(),t=I.value.getOption();return`<template>
    <form-create
      v-model:api="fApi"
      :rule="rule"
      :option="option"
      @submit="onSubmit"
    ></form-create>
  </template>
  <script setup lang=ts>
    const faps = ref(null)
    const rule = ref('')
    const option = ref('')
    const init = () => {
      rule.value = formCreate.parseJson('${v.toJson(e).replaceAll(`\\`,`\\\\`)}')
      option.value = formCreate.parseJson('${JSON.stringify(t)}')
    }
    const onSubmit = (formData) => {
      //todo 提交表单
    }
    init()
  <\/script>`},K=async e=>{let{copy:t,copied:n,isSupported:r}=D({legacy:!0,source:JSON.stringify(e,null,2)});r?(await t(),_(n)&&x.success(g(`common.copySuccess`))):x.error(g(`common.copyError`))},q=e=>{let t=`json`;return z.value===2&&(t=`xml`),w(e)||(e=JSON.stringify(e,null,2)),A.highlight(e,{language:t,ignoreIllegals:!0}).value||`&nbsp;`};return t(async()=>{A.registerLanguage(`xml`,j),A.registerLanguage(`json`,M)}),(t,o)=>{let u=c,v=i(`fc-designer`),x=k,C=d,w=O,T=s(`dompurify-html`);return a(),f(e,null,[h(x,{"body-style":{padding:`0px`},class:`!mb-0`},{default:r(()=>[l(`div`,N,[h(v,{class:`my-designer`,ref_key:`designer`,ref:I,config:_(S)},{handle:r(()=>[h(u,{size:`small`,type:`primary`,plain:``,onClick:H},{default:r(()=>[...o[2]||=[p(`生成JSON`,-1)]]),_:1}),h(u,{size:`small`,type:`success`,plain:``,onClick:U},{default:r(()=>[...o[3]||=[p(`生成Options`,-1)]]),_:1}),h(u,{size:`small`,type:`danger`,plain:``,onClick:W},{default:r(()=>[...o[4]||=[p(`生成组件`,-1)]]),_:1})]),_:1},8,[`config`])])]),_:1}),h(w,{modelValue:_(L),"onUpdate:modelValue":o[1]||=e=>m(L)?L.value=e:null,title:_(R),"max-height":`600`},{default:r(()=>[_(L)?(a(),f(`div`,P,[h(u,{style:{float:`right`},onClick:o[0]||=e=>K(_(B))},{default:r(()=>[p(n(_(g)(`common.copy`)),1)]),_:1}),h(C,{height:`580`},{default:r(()=>[l(`div`,null,[l(`pre`,null,[y(l(`code`,F,null,512),[[T,q(_(B))]])])])]),_:1})],512)):b(``,!0)]),_:1},8,[`modelValue`,`title`])],64)}}});export{I as default};