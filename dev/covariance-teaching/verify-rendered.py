#!/usr/bin/env python3
import hashlib, json, re
from pathlib import Path
from html.parser import HTMLParser
class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.images=[]; self.assets=[]; self.text=[]
    def handle_data(self, value): self.text.append(value)
    def handle_starttag(self, tag, attributes):
        a=dict(attributes)
        if tag=='img': self.images.append(a)
        if tag in ('img','script') and a.get('src'): self.assets.append(a['src'])
        if tag=='link' and a.get('rel')=='stylesheet': self.assets.append(a['href'])
names=['covariance-correlation','cross-family-correlations','spatial-models']
targets={'covariance-correlation':['corr-comparison','sigma-table-plot','communality-correlation-matrix'], 'cross-family-correlations':['recover-plot']}
phrases={
 'covariance-correlation':['Shared factors are therefore not required at every level','unevaluated','structural translation','whether that decomposition is identifiable','NB/Tweedie-plus-OLRE'],
 'cross-family-correlations':['not repeated-simulation recovery evidence','not a correlation of observed responses','does not demonstrate long/wide fit parity','sampling, estimation, and optimization'],
 'spatial-models':['Different positive diagonal Psi companions','structural decomposition ambiguity','total spatial covariance is the intended covariance target','unevaluated structural translations']}
normalize=lambda s: re.sub(r'\s+',' ',s).strip()
results={}
for name in names:
    html=Path('pkgdown-site/articles')/(name+'.html')
    page=Page();page.feed(html.read_text())
    text=normalize(' '.join(page.text))
    missing=[phrase for phrase in phrases[name] if phrase not in text]
    assert not missing, (name,missing)
    for asset in page.assets:
        if not asset.startswith(('http:','https:','data:','//')):
            p=html.parent/asset
            assert p.exists() and p.stat().st_size>0, (name,'missing asset',asset)
    alts=[]
    source=Path('vignettes/articles')/(name+'.Rmd')
    for label in targets.get(name,[]):
        images=[i for i in page.images if '/'+label+'-' in i.get('src','')]
        assert len(images)==1, (name,label,images)
        alt=normalize(images[0].get('alt',''))
        match=re.search(r'^```\{r '+re.escape(label)+r'[^\n]*fig.alt = "([^"]+)"',source.read_text(),re.M)
        assert match and alt==normalize(match[1]) and len(alt)>50, (name,label,alt)
        alts.append({'chunk':label,'alt':alt,'image':images[0]['src']})
    results[name]={'html_sha256':hashlib.sha256(html.read_bytes()).hexdigest(), 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'alt_attributes':alts,'assets_checked':len(page.assets),'phrases_checked':phrases[name]}
Path('dev/covariance-teaching/rendered-verification.json').write_text(json.dumps(results,indent=2)+'\n')
print('RENDERED_MEANINGS_FOUR_ALTS_AND_ASSETS_VERIFIED')
