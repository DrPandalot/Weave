/*
	Weave (Web-based Analysis and Visualization Environment)
	Copyright (C) 2008-2011 University of Massachusetts Lowell
	
	This file is a part of Weave.
	
	Weave is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License, Version 3,
	as published by the Free Software Foundation.
	
	Weave is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.servlets;

import java.io.File;
import java.rmi.RemoteException;
import java.util.HashMap;
import java.util.UUID;
import java.util.Vector;

import javax.script.Bindings;
import javax.script.ScriptContext;
import javax.script.ScriptEngine;
import javax.script.ScriptEngineManager;
import javax.script.ScriptException;

import weave.beans.RResult;
import weave.config.WeaveConfig;
 
public class RServiceUsingJRI
{
	public RServiceUsingJRI()
	{
	}

	private static String rFolderName = "R_output";
	
	private static RScriptEngine engine = null;
	
	public static class JRIConnectionException extends RemoteException
	{
		private static final long serialVersionUID = 1L;

		public JRIConnectionException(Throwable e)
		{
			super("Unable to initialize REngine",e);
		}
	}
	
	public static RScriptEngine getREngine() throws RemoteException
	{
		try
		{
			String extension = "R";
			ScriptEngineManager manager = new ScriptEngineManager();
			RScriptEngine engine = (RScriptEngine)manager.getEngineByExtension(extension);
			//Happens when JRI native Library not found - engine will be null
			// as We set System.setProperty("jri.ignore.ule", "yes");
			// in getScriptEngine method of RScriptFactory class 
			if(engine == null){
				throw new RemoteException( "Native Library not found");
			}
			return engine;
		}
		catch (Throwable e)
		{
			throw new JRIConnectionException(e);
		}
	}

	/**
	 * Use this as a security measure. This will fail if Rserve has file access to sqlconfig.xml.
	 */
	private static void requestScriptAccess(RScriptEngine engine) throws RemoteException
	{
		if (!WeaveConfig.getPropertyBoolean(WeaveConfig.ALLOW_R_SCRIPT_ACCESS))
		{
			engine.close(); // must close before throwing exception
			throw new RemoteException("R script access is not permitted on this server.");
		}
		
		if (WeaveConfig.getPropertyBoolean(WeaveConfig.ALLOW_RSERVE_ROOT_ACCESS))
			return;
		
		try
		{
			assignNamesToVector(new String[]{".tmp"}, new Object[]{WeaveConfig.getConnectionConfigFilePath()}, null, false);
			Object result = engine.eval("length(readLines(.tmp.))");
			assignNamesToVector(new String[]{".tmp"}, new Object[]{null}, null, false);
			engine.close(); // must close before throwing exception
			if (result instanceof Number)
				throw new RemoteException("R script access is not allowed because it is unsafe (The user running Rserve has file read/write access).");
			throw new RemoteException("Unexpected result in requestScriptAccess(): " + result);
		}
		catch (ScriptException e)
		{
			// this exception is desired because we don't want users to be able to read or write files.
		}
	}
	
	public static RResult[] runScript(String docrootPath, String[] keys,String[] inputNames, Object[] inputValues, String[] outputNames, String script, String plotScript, boolean showIntermediateResults, boolean showWarnings ,boolean useColumnAsList) throws RemoteException
	{	
		engine = null;
		engine = getREngine();
		requestScriptAccess(engine);
		
		synchronized (engine) {		
			RResult[] results = null;
			Vector<RResult> resultVector = new Vector<RResult>();
			try
			{
				assignNamesToVector( inputNames, inputValues, keys, useColumnAsList);
				evaluateInputScript( script, resultVector, showIntermediateResults, showWarnings );
				if (plotScript != ""){// R Script to EVALUATE plotScript
					String plotEvalValue = plotEvalScript(engine,docrootPath, plotScript, showWarnings);
					resultVector.add(new RResult("Plot Results", plotEvalValue));
				}
				for (int i = 0; i < outputNames.length; i++){// R Script to EVALUATE output Script
					String name = outputNames[i];						
					Object evalValue = evalScript(engine, name, showWarnings);					
					resultVector.add(new RResult(name, evalValue));					
				}
				// to clear R objects
				evalScript(engine, "rm(list=ls())", false);
			}
			//Happens when JRI native Library not found - engine will be null
			// as We set System.setProperty("jri.ignore.ule", "yes");
			// in getScriptEngine method of RScriptFactory class 
			catch (Exception e)
			{
				throw new RemoteException("Unable to run R script", e);
			}
			finally
			{
				results = new RResult[resultVector.size()];
				resultVector.toArray(results);
				((RScriptEngine)engine).close();			
			}
			return results;
		}		
	}
	
	
	@SuppressWarnings({ "rawtypes", "unchecked" })
	private static void assignNamesToVector(String[] inputNames,Object[] inputValues,String[] keys,boolean useColumnAsList)
	{
		// ASSIGNS inputNames to respective Vector in R "like x<-c(1,2,3,4)"
		Bindings bindedVectors = engine.createBindings();//engine needs to be static , otherwise throws null point error
		for (int i = 0; i < inputNames.length; i++){
			String name = inputNames[i];
			if (useColumnAsList) //if column to consider as list in R
			{
				HashMap hm = new HashMap();
				
				//TODO: support more than just vectors
				Object[] array = (Object[])inputValues[i];
				
				for(int keyID = 0; keyID < keys.length ;keyID++)
					hm.put(keys[keyID], array[keyID]);
				bindedVectors.put(name, hm);
			}
			else				
				bindedVectors.put(name, inputValues[i]);
		}
		engine.setBindings(bindedVectors, ScriptContext.ENGINE_SCOPE);	
	}
	private static void evaluateInputScript(String script,Vector<RResult> resultVector,boolean showIntermediateResults,boolean showWarnings ) throws ScriptException
	{
		evalScript(engine, script, showWarnings);
		if (showIntermediateResults){
			Object storedRdatas = evalScript(engine, "ls()", showWarnings);
			if(storedRdatas instanceof String[]){
				String[] Rdatas =(String[])storedRdatas;
				for(int i=0;i<Rdatas.length;i++){
					String scriptToAcessRObj = Rdatas[i];
					if(scriptToAcessRObj.compareTo("mycache") == 0)
						continue;
					Object RobjValue = evalScript(engine, scriptToAcessRObj, false);
					//When function reference is called returns null
					if(RobjValue == null)
						continue;
					resultVector.add(new RResult(scriptToAcessRObj, RobjValue));	
				}
			}			
		}
	}
	
	
	private static Object evalScript(ScriptEngine engine, String script, boolean showWarnings) throws ScriptException
	{
		Object evalValue = null;
		if(showWarnings)			
			evalValue = engine.eval("try({ options(warn=2) \n" + script + "},silent=TRUE)");			
		else
			evalValue = engine.eval("try({ options(warn=1) \n" + script + "},silent=TRUE)");
		return evalValue;
		
	}
	
	private static String plotEvalScript(ScriptEngine engine,String docrootPath,String script, boolean showWarnings) throws ScriptException
	{
		String file = String.format("user_script_%s.jpg", UUID.randomUUID());
		String dir = docrootPath + rFolderName + "/";
		(new File(dir)).mkdirs();
		
		String str = null;
		try
		{
			str = String.format("jpeg(\"%s\")", dir + file);
			evalScript(engine, str, showWarnings);
			
			engine.eval(str = script);
			engine.eval(str = "dev.off()");
		}
		catch (ScriptException e)
		{
			System.err.println(str);
			throw e;
		}
		
		return rFolderName + "/" + file;
	}
}
