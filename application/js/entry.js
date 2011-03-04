console.log('Loading Entry...')

Spontaneous.Entry = (function($, S) {
	var dom = S.Dom;
	var debug = 0;
	var Entry = new JS.Class(Spontaneous.Content, {
		initialize: function(content, container) {
			this.container = container;
			this.callSuper(content);
			// this.content = content;
			// console.log('FacetEntry#new', content, content.depth);
		},
		panel: function() {
			var wrapper = $(dom.div, {'class':['entry-wrap ', this.depth_class(), this.visibility_class()].join(' ')});
			var outline = $(dom.div, {'class':'white-bg'}).mouseover(this.mouseover.bind(this)).mouseout(this.mouseout.bind(this)).click(this.edit.bind(this))
			wrapper.append(outline)
			if (this.depth() < 4) {
				wrapper.append($(dom.div, {'class':'grey-bg'}));
			}
			wrapper.append(this.title_bar(wrapper));
			var edit_slot = $(dom.div, {'style':'position: relative;overflow:visible'})
			var edit_wrapper = $(dom.div, {'style':'position: absolute; z-index:4;left: -4px; top: 0; right: -4px;'});
			edit_slot.append(edit_wrapper);
			var inside = $(dom.div, {'class':'clearfix'});
			wrapper.append(edit_slot);
			wrapper.append(inside);
			this.dialogue_box = $(dom.div, {'class':'dialogue', 'style':'display: none'});
			wrapper.append(this.dialogue_box);
			var entry = $(dom.div, {'class':'entry'});
			var fields = new Spontaneous.FieldPreview(this, '');
			entry.append(fields.panel());
			// console.log("Entry#panel", this.entries())
			var box_container = new Spontaneous.BoxContainer(this);
			inside.append(entry);
			inside.append(box_container.panel());
			this.wrapper = wrapper;
			this.outline = outline;
			this.edit_wrapper = edit_wrapper;
			this.inside = inside;
			return wrapper;
		},
		edit: function() {
			var panel = this.callSuper(), view = panel.view(), w = this.edit_wrapper, i = this.inside;
			if (!i.data('height')) {
				i.data('height', i.height());
				console.log('inner height', i.data('height'), this.inside)
			}
			w.append(view);
			w.add(this.inside).animate({'height':view.height()}, 200, function() {
			});
		},
		edit_closed: function() {
			var w = this.edit_wrapper, t = 200, inside = this.inside;
			inside.animate({'height':inside.data('height')}, t, function() {
				inside.css('height', 'auto')
			});
			w.animate({'height':''}, t, function() {
				w.empty();
			})
		},
		title_bar: function(wrapper) {
			if (!this._title_bar) {
				var title_bar = $(dom.div, {'class':'title-bar'});
				var actions = $(dom.div, {'class':'actions', 'xstyle':'display: none'});
				var destroy = $(dom.a, {'class':'delete'});
				var visibility = $(dom.a, {'class':'visibility'});
				actions.append(destroy);
				actions.append(visibility);
				title_bar.append(actions);
				var _hide_pause;
				// wrapper.mouseenter(function() {
				// 	if (_hide_pause) { window.clearTimeout(_hide_pause); }
				// 	actions.slideDown(50);
				// }).mouseleave(function() {
				// 	_hide_pause = window.setTimeout(function() { actions.slideUp(100) }, 200);
				// });
				destroy.click(this.confirm_destroy.bind(this));
				visibility.click(this.toggle_visibility.bind(this));
				this._title_bar = title_bar;
			}
			return this._title_bar;
		},
		visibility_toggled: function(result) {
			this.wrapper.removeClass('visible hidden');
			if (result.hidden) {
				this.wrapper.switchClass('visible', 'hidden', 200);
			} else {
				this.wrapper.switchClass('hidden', 'visible', 200);
			}
		},
		mouseover: function() {
			this.outline.addClass('active');
		},
		mouseout: function() {
			this.outline.removeClass('active');
		},
		confirm_destroy: function() {
			var d = this.dialogue_box;
			d.empty();
			var msg = $(dom.p, {'class':'message'}).text('Are you sure you want to delete this?');
			var btns = $(dom.div, {'class':'buttons'});
			var ok = $(dom.a, {'class':'default'}).text("Delete").click(function() {
				this.dialogue_box.slideUp(100, function() {
					this.wrapper.fadeTo(100, 0.5);
					this.destroy();
				}.bind(this));
				return false;
			}.bind(this))

			var cancel = $(dom.a).text("Cancel").click(function() {
				this.dialogue_box.slideUp();
				return false;
			}.bind(this));
			btns.append(ok).append(cancel);
			d.append(msg).append(btns);
			d.slideDown(200);
		},
		destroyed: function() {
			console.log('Entry.destroyed', this.content)
			this.wrapper.slideUp(200, function() {
				this.wrapper.remove();
			}.bind(this));
		}
	});
	return Entry;
})(jQuery, Spontaneous);
