#!/usr/bin/env python3
"""Render Tripo GLBs as reference previews; no changes to mesh or rig."""
import argparse
from pathlib import Path
import numpy as np
import trimesh
import vtk
from vtk.util.numpy_support import numpy_to_vtk, numpy_to_vtkIdTypeArray, vtk_to_numpy
from PIL import Image, ImageDraw

def render(scene, position, width=640, height=890):
    center=scene.bounds.mean(axis=0)
    size=max(scene.extents)
    renderer=vtk.vtkRenderer(); renderer.SetBackground(.94,.955,.975)
    for geometry in scene.dump():
        if not isinstance(geometry,trimesh.Trimesh) or len(geometry.faces)==0: continue
        poly=vtk.vtkPolyData(); pts=vtk.vtkPoints()
        pts.SetData(numpy_to_vtk(np.asarray(geometry.vertices,dtype=np.float32),deep=True))
        poly.SetPoints(pts)
        faces=np.asarray(geometry.faces,dtype=np.int64)
        legacy=np.column_stack([np.full(len(faces),3),faces]).astype(np.int64).ravel()
        cells=vtk.vtkCellArray(); cells.SetCells(len(faces),numpy_to_vtkIdTypeArray(legacy,deep=True))
        poly.SetPolys(cells)
        normals=vtk.vtkPolyDataNormals(); normals.SetInputData(poly); normals.SplittingOff(); normals.Update()
        mapper=vtk.vtkPolyDataMapper(); mapper.SetInputConnection(normals.GetOutputPort())
        actor=vtk.vtkActor(); actor.SetMapper(mapper)
        actor.GetProperty().SetColor(.70,.76,.84)
        actor.GetProperty().SetAmbient(.4); actor.GetProperty().SetDiffuse(.55)
        renderer.AddActor(actor)
    offset=np.array(position,dtype=float); offset=offset/np.linalg.norm(offset)*size*4
    camera=vtk.vtkCamera(); camera.SetFocalPoint(*center); camera.SetPosition(*(center+offset)); camera.SetViewUp(0,1,0)
    camera.ParallelProjectionOn(); camera.SetParallelScale(size*.65)
    renderer.SetActiveCamera(camera)
    lamp=vtk.vtkLight(); lamp.SetPosition(*(center+np.array([2,3,4])*size))
    lamp.SetFocalPoint(*center); lamp.SetIntensity(.85); renderer.AddLight(lamp)
    window=vtk.vtkRenderWindow(); window.SetSize(width,height); window.SetOffScreenRendering(True)
    window.SetMultiSamples(0); window.AddRenderer(renderer); window.Render()
    grab=vtk.vtkWindowToImageFilter(); grab.SetInput(window); grab.SetInputBufferTypeToRGB()
    grab.ReadFrontBufferOff(); grab.Update()
    array=vtk_to_numpy(grab.GetOutput().GetPointData().GetScalars()).reshape(height,width,3)[::-1]
    image=Image.fromarray(np.array(array,copy=True)); window.Finalize()
    return image

def main():
    p=argparse.ArgumentParser(); p.add_argument('glb'); p.add_argument('--out',required=True); p.add_argument('--gender',required=True)
    a=p.parse_args()
    scene=trimesh.load(a.glb,force='scene',process=False)
    if not len(scene.geometry): raise RuntimeError('empty Tripo mesh')
    angles=[('FRONT',(0,0,3)),('THREE-QUARTER',(2,.8,3)),('SIDE',(3,0,0))]
    result=Image.new('RGB',(640*3,950),'white'); draw=ImageDraw.Draw(result)
    draw.text((20,15),f'AETHERFALL / {a.gender.upper()} / TRIPO UNTEXTURED CANDIDATE / NOT YET RIGGED',fill=(20,30,40))
    for i,(name,cam) in enumerate(angles):
        img=render(scene,cam); result.paste(img,(640*i,50))
        draw.text((i*640+24,65),name,fill=(40,50,60))
    Path(a.out).parent.mkdir(parents=True,exist_ok=True)
    result.save(a.out)
    print('REVIEW_PREVIEW_OK',a.out,'geometry',len(scene.geometry),'bounds',scene.bounds.tolist())

if __name__=='__main__': main()
