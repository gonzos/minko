package aerys.minko.scene.node
{
	import aerys.minko.ns.minko_scene;
	import aerys.minko.scene.SceneIterator;
	import aerys.minko.scene.controller.AbstractController;
	import aerys.minko.type.Signal;
	import aerys.minko.type.Sort;
	import aerys.minko.type.loader.ILoader;
	import aerys.minko.type.loader.SceneLoader;
	import aerys.minko.type.loader.parser.ParserOptions;
	import aerys.minko.type.math.Matrix4x4;
	import aerys.minko.type.math.Ray;
	
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	import flash.utils.getQualifiedClassName;

	use namespace minko_scene;
	
	/**
	 * Group objects can contain other scene nodes and applies a 3D
	 * transformation to its descendants.
	 *
	 * @author Jean-Marc Le Roux
	 */
	public class Group extends AbstractSceneNode
	{
		minko_scene var _children		: Vector.<ISceneNode>	= null;
		minko_scene var _numChildren	: uint					= 0;
		
		private var _numDescendants		: uint					= 0;
		
		private var _descendantAdded	: Signal				= new Signal('Group.descendantAdded');
		private var _descendantRemoved	: Signal				= new Signal('Group.descendantRemoved');

		/**
		 * The number of children of the Group.
		 */
		public function get numChildren() : uint
		{
			return _numChildren;
		}
		
		/**
		 * The number of descendants of the Group.
		 *  
		 * @return 
		 * 
		 */
		public function get numDescendants() : uint
		{
			return _numDescendants;
		}
		
		/**
		 * The signal executed when a descendant is added to the Group.
		 * Callbacks for this signal must accept the following arguments:
		 * <ul>
		 * <li>newParent : Group, the Group the descendant was actually added to</li>
		 * <li>descendant : ISceneNode, the descendant that was just added</li>
		 * </ul>
		 *  
		 * @return 
		 * 
		 */
		public function get descendantAdded() : Signal
		{
			return _descendantAdded
		}
		
		/**
		 * The signal executed when a descendant is removed from the Group.
		 * Callbacks for this signal must accept the following arguments:
		 * <ul>
		 * <li>oldParent : Group, the Group the descendant was actually removed from</li>
		 * <li>descendant : ISceneNode, the descendant that was just removed</li>
		 * </ul>
		 *  
		 * @return 
		 * 
		 */
		public function get descendantRemoved() : Signal
		{
			return _descendantRemoved;
		}
		
		public function Group(...children)
		{
			super();

			initialize();
			initializeChildren(children);
		}

		private function initialize() : void
		{
			_children = new <ISceneNode>[];

			descendantAdded.add(descendantAddedHandler);
			descendantRemoved.add(descendantRemovedHandler);
		}
		
		protected function initializeChildren(children : Array) : void
		{
			while (children.length == 1 && children[0] is Array)
				children = children[0];
			
			var childrenNum : uint = children.length;
			
			for (var childrenIndex : uint = 0; childrenIndex < childrenNum; ++childrenIndex)
				addChild(ISceneNode(children[childrenIndex]));
		}
		
		override protected function addedHandler(child : ISceneNode, parent : Group) : void
		{
			super.addedHandler(child, parent);
			
			for (var childIndex : int = 0; childIndex < _numChildren; ++childIndex)
				_children[childIndex].added.execute(child, parent);
		}
		
		override protected function removedHandler(child : ISceneNode, parent : Group) : void
		{
			super.removedHandler(child, parent);
			
			for (var childIndex : int = 0; childIndex < _numChildren; ++childIndex)
				_children[childIndex].removed.execute(child, parent);
		}
		
		private function descendantAddedHandler(group : Group, child : ISceneNode) : void
		{
			if (group == this)
			{
				var childGroup : Group = child as Group;
				
				if (childGroup)
				{
					childGroup.descendantAdded.add(_descendantAdded.execute);
					childGroup.descendantRemoved.add(_descendantRemoved.execute);
				}
			}
			
			_numDescendants += (child is Group) ? (child as Group)._numDescendants + 1 : 1;
		}
		
		private function descendantRemovedHandler(group : Group, child : ISceneNode) : void
		{
			if (group == this)
			{
				var childGroup : Group = child as Group;
				
				if (childGroup)
				{
					childGroup.descendantAdded.remove(_descendantAdded.execute);
					childGroup.descendantRemoved.remove(_descendantRemoved.execute);
				}
			}
			
			_numDescendants -= (child is Group) ? (child as Group)._numDescendants + 1 : 1;
		}
		
		/**
		 * Return true if the specified scene node is a child of the Group, false otherwise.
		 *  
		 * @param scene
		 * @return 
		 * 
		 */
		public function contains(scene : ISceneNode) : Boolean
		{
			return getChildIndex(scene) >= 0;
		}

		/**
		 * Return the index of the speficied scene node or -1 if it is not in the Group.
		 *  
		 * @param child
		 * @return 
		 * 
		 */
		public function getChildIndex(child : ISceneNode) : int
		{
			if (child == null)
				throw new Error('The \'child\' parameter cannot be null.');
			
			for (var i : int = 0; i < _numChildren; i++)
				if (_children[i] === child)
					return i;

			return -1;
		}

		public function getChildByName(name : String) : ISceneNode
		{
			for (var i : int = 0; i < _numChildren; i++)
				if (_children[i].name === name)
					return _children[i];

			return null;
		}

		/**
		 * Add a child to the group.
		 *
		 * @param	scene The child to add.
		 */
		public function addChild(node : ISceneNode) : Group
		{
			return addChildAt(node, _numChildren);
		}

		/**
		 * Add a child to the group at the specified position.
		 *  
		 * @param node
		 * @param position
		 * @return 
		 * 
		 */
		public function addChildAt(node : ISceneNode, position : uint) : Group
		{
			if (!node)
				throw new Error('Parameter \'scene\' must not be null.');

			node.parent = this;

			for (var i : int = _numChildren - 1; i > position; --i)
				_children[i] = _children[int(i - 1)];
			
			_children[position] = node;
			
			return this;
		}

		/**
		 * Remove a child from the container.
		 *
		 * @param	myChild The child to remove.
		 * @return Whether the child was actually removed or not.
		 */
		public function removeChild(child : ISceneNode) : Group
		{
			return removeChildAt(getChildIndex(child));
		}

		public function removeChildAt(position : uint) : Group
		{
			if (position >= _numChildren || position < 0)
				throw new Error('The scene node is not a child of the caller.');
			
			(_children[position] as ISceneNode).parent = null;

			return this;
		}

		/**
		 * Remove all the children.
		 *  
		 * @return 
		 * 
		 */
		public function removeAllChildren() : Group
		{
			while (_numChildren)
				removeChildAt(0);

			return this;
		}

		/**
		 * Return the child at the specified position.
		 *  
		 * @param position
		 * @return 
		 * 
		 */
		public function getChildAt(position : uint) : ISceneNode
		{
			return position < _numChildren ? _children[position] : null;
		}

		/**
		 * Returns the list of descendant scene nodes that have the specified type. 
		 *  
		 * @param type
		 * @param descendants
		 * @return 
		 * 
		 */
		public function getDescendantsByType(type 			: Class,
											 descendants 	: Vector.<ISceneNode> = null) : Vector.<ISceneNode>
		{
			descendants ||= new Vector.<ISceneNode>();

			for (var i : int = 0; i < _numChildren; ++i)
			{
				var child	: ISceneNode	= _children[i];
				var group 	: Group 		= child as Group;

				if (child is type)
					descendants.push(child);

				if (group)
					group.getDescendantsByType(type, descendants);
			}

			return descendants;
		}
		
		public function toString() : String
		{
			return '[' + getQualifiedClassName(this) + ' ' + name + ']';
		}

		/**
		 * Load the 3D scene corresponding to the specified URLRequest object
		 * and add it directly to the group.
		 *  
		 * @param request
		 * @param options
		 * @return 
		 * 
		 */
		public function load(request	: URLRequest,
							 options	: ParserOptions	= null) : ILoader
		{
			var loader	: SceneLoader	= new SceneLoader(options);
			
			loader.complete.add(loaderCompleteHandler);
			loader.load(request);
			
			return loader;
		}
		
		/**
		 * Load the 3D scene corresponding to the specified Class object
		 * and add it directly to the group.
		 *  
		 * @param classObject
		 * @param options
		 * @return 
		 */
		public function loadClass(classObject	: Class,
								  options		: ParserOptions	= null) : SceneLoader
		{
			var loader : SceneLoader = new SceneLoader(options);
			
			loader.complete.add(loaderCompleteHandler);
			loader.loadClass(classObject);
			
			return loader;
		}
		
		/**
		 * Load the 3D scene corresponding to the specified ByteArray object
		 * and add it directly to the group.
		 *  
		 * @param bytes
		 * @param options
		 * @return 
		 * 
		 */
		public function loadBytes(bytes		: ByteArray,
								  options	: ParserOptions	= null) : ILoader
		{
			var loader	: SceneLoader	= new SceneLoader(options);
			
			loader.complete.add(loaderCompleteHandler);
			loader.loadBytes(bytes);
			
			return loader;
		}
		
		/**
		 * Return the set of nodes matching the specified XPath query.
		 *  
		 * @param xpath
		 * @return 
		 * 
		 */
		public function get(xpath : String) : SceneIterator
		{
			return new SceneIterator(xpath, new <ISceneNode>[this]);
		}
		
		private function loaderCompleteHandler(loader	: ILoader,
											   scene	: ISceneNode) : void
		{
			addChild(scene);
		}
		
		/**
		 * Return all the Mesh objects hit by the specified ray.
		 *  
		 * @param ray
		 * @param maxDistance
		 * @return 
		 * 
		 */
		public function cast(ray : Ray, maxDistance : Number = Number.POSITIVE_INFINITY) : SceneIterator
		{
			var meshes		: Vector.<ISceneNode> 	= getDescendantsByType(Mesh);
			var numMeshes	: uint					= meshes.length;
			var hit			: Array					= [];
			var depth		: Vector.<Number>		= new <Number>[];
			var numItems	: uint					= 0;
			
			for (var i : uint = 0; i < numMeshes; ++i)
			{
				var mesh 		: Mesh		= meshes[i] as Mesh;
				var hitDepth	: Number	= mesh.cast(ray, maxDistance);
				
				if (hitDepth >= 0.0)
				{
					hit[numItems] = mesh;
					depth[numItems] = hitDepth;
					++numItems;
				}
			}
			
			if (numItems > 1)
				Sort.flashSort(depth, hit, numItems);
			
			return new SceneIterator(null, Vector.<ISceneNode>(hit));
		}
		
		override minko_scene function cloneNode() : AbstractSceneNode
		{
			var clone : Group = new Group();
			
			clone.name = name;
			clone.transform.copyFrom(transform);
			
			for (var childId : uint = 0; childId < _numChildren; ++childId)
			{
				var child		: AbstractSceneNode = AbstractSceneNode(_children[childId]);
				var clonedChild	: AbstractSceneNode = AbstractSceneNode(child.cloneNode());
				
				clone.addChild(clonedChild);
			}
			
			return clone;
		}
	}
}
