import{_ as s,c as i,o as a,a7 as n}from"./chunks/framework.-tkVdUys.js";const y=JSON.parse('{"title":"Bake sysimage with PackageCompiler.jl","description":"","frontmatter":{},"headers":[],"relativePath":"advanced/reduce_latency.md","filePath":"advanced/reduce_latency.md","lastUpdated":null}'),l={name:"advanced/reduce_latency.md"},t=n(`<h1 id="Bake-sysimage-with-PackageCompiler.jl" tabindex="-1">Bake <code>sysimage</code> with <code>PackageCompiler.jl</code> <a class="header-anchor" href="#Bake-sysimage-with-PackageCompiler.jl" aria-label="Permalink to &quot;Bake \`sysimage\` with \`PackageCompiler.jl\` {#Bake-sysimage-with-PackageCompiler.jl}&quot;">​</a></h1><p>You can bake a sysimage tailored for your analysis to reduce latency.</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> cat readtree</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">jl</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> UnROOT</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">const</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> r </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> ROOTFile</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;/home/akako/.julia/dev/UnROOT/test/samples/NanoAODv5_sample.root&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">const</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> t </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> LazyTree</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(r, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Events&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, [</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;nMuon&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Electron_dxy&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">])</span></span>
<span class="line"></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">@show</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> t[</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:Electron_dxy</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">]</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> time julia </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">--</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">startup</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">-</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">file</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">no readtree</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">jl</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">t[</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:Electron_dxy</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">] </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Float32[</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.00037050247</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">]</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">________________________________________________________</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">Executed </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">in</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">   10.82</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> secs    fish           external</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">   usr time   </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">11.09</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> secs  </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">580.00</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> micros   </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">11.09</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> secs</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">   sys time    </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.65</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> secs  </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">189.00</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> micros    </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.65</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> secs</span></span></code></pre></div><p>In Julia, \`]add PackageCompiler&#39;:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> PackageCompiler</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">julia</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> PackageCompiler</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">create_sysimage</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:UnROOT</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">; precompile_statements_file</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;./readtree.jl&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, sysimage_path</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;./unroot.so&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, replace_default</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">false</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&#39;</span></span></code></pre></div><p>profit:</p><div class="language-fish vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">fish</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> time julia -J ./unroot.so readtree.jl </span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">t[1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, :Electron_dxy] = Float32[0.00037050247]</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">________________________________________________________</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Executed</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> in</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">  619.20 millis    fish           external</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">   usr</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> time  902.29 millis    0.00 millis  902.29 millis</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">   sys</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> time  658.59 millis    1.05 millis  657.54 millis</span></span></code></pre></div>`,7),h=[t];function k(e,p,E,r,d,_){return a(),i("div",null,h)}const c=s(l,[["render",k]]);export{y as __pageData,c as default};